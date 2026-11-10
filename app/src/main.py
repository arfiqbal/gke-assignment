"""Build-info service: FastAPI app with health checks, optional TLS and graceful termination."""
import json
import logging
import platform
import sys
import threading
import time
import uuid

import uvicorn
from fastapi import FastAPI, Request, Response

from config import Settings

settings = Settings.from_env()

BUILD_INFO = {
    "version": settings.version,
    "commit_sha": settings.commit_sha,
    "build_time": settings.build_time,
    "python_version": platform.python_version(),
}


# ---------- structured JSON logging ----------
class JsonFormatter(logging.Formatter):
    def format(self, record):
        payload = {
            "severity": record.levelname,
            "message": record.getMessage(),
            "time": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
        }
        payload.update(getattr(record, "extra_fields", {}))
        return json.dumps(payload)


# Logs go to stdout only (12-factor): no log files; the container runtime / GKE collects stdout.
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
for name in ("app", "uvicorn", "uvicorn.error"):   # route uvicorn's own logs through the same handler
    lg = logging.getLogger(name)
    lg.setLevel(settings.log_level)
    lg.handlers = [handler]
    lg.propagate = False
logger = logging.getLogger("app")


# ---------- shared state ----------
class State:
    shutting_down = False


state = State()
app = FastAPI(title="build-info", docs_url=None, redoc_url=None)


@app.middleware("http")
async def request_logging(request: Request, call_next):
    request_id = request.headers.get("x-request-id", str(uuid.uuid4()))
    start = time.perf_counter()
    response = await call_next(request)
    response.headers["x-request-id"] = request_id
    if request.url.path not in ("/healthz", "/readyz"):  # keep probe noise out of logs
        logger.info(
            "request",
            extra={"extra_fields": {
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status": response.status_code,
                "duration_ms": round((time.perf_counter() - start) * 1000, 2),
            }},
        )
    return response


# ---------- endpoints ----------
@app.get("/api/v1/build-info")
def build_info():
    return BUILD_INFO


@app.get("/healthz")
def liveness():
    """Liveness: process is up. Never depends on downstreams or shutdown state."""
    return {"status": "ok"}


@app.get("/readyz")
def readiness(response: Response):
    """Readiness: fails once SIGTERM is received so the NEG/LB stops sending traffic."""
    if state.shutting_down:
        response.status_code = 503
        return {"status": "shutting_down"}
    return {"status": "ready"}


# ---------- graceful termination ----------
class GracefulServer(uvicorn.Server):
    """On SIGTERM/SIGINT: fail readiness first, wait for the LB to drain,
    then let uvicorn stop accepting connections and finish in-flight requests."""

    def handle_exit(self, sig, frame):
        if state.shutting_down:                  # second signal -> force quit
            super().handle_exit(sig, frame)
            return
        state.shutting_down = True
        logger.info(f"signal {sig} received, readiness failing, draining for {settings.drain_delay}s")
        threading.Timer(settings.drain_delay, super().handle_exit, args=(sig, frame)).start()

    async def shutdown(self, sockets=None):
        logger.info("drain finished, stopping listeners and finishing in-flight requests")
        await super().shutdown(sockets=sockets)
        logger.info("shutdown complete")


def build_uvicorn_config(s: Settings) -> uvicorn.Config:
    kwargs = {}
    if s.tls:
        kwargs.update(ssl_certfile=s.tls_cert_file, ssl_keyfile=s.tls_key_file)
    return uvicorn.Config(
        app,
        host="0.0.0.0",
        port=s.port,
        log_config=None,
        access_log=False,
        timeout_graceful_shutdown=s.shutdown_timeout,
        **kwargs,
    )


def main():
    settings.validate()
    scheme = "https" if settings.tls else "http"
    logger.info(f"starting {scheme} server on :{settings.port}")
    GracefulServer(build_uvicorn_config(settings)).run()


if __name__ == "__main__":
    main()
