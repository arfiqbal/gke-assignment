"""All runtime configuration comes from environment variables (injected from a ConfigMap)."""
import json
import os
from dataclasses import dataclass


def _bool(name: str, default: bool) -> bool:
    return os.getenv(name, str(default)).strip().lower() in ("1", "true", "yes", "on")


def _load_build_file(path: str) -> dict:
    """Build metadata written into the image at build time. Missing/invalid file -> empty dict."""
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def _pick(env_name: str, file_data: dict, key: str, default: str) -> str:
    """Precedence: env var (e.g. from ConfigMap) > build file > default."""
    value = os.getenv(env_name)
    if value:
        return value
    return str(file_data.get(key) or default)


@dataclass(frozen=True)
class Settings:
    port: int = 8080
    tls: bool = False
    tls_cert_file: str = "/etc/tls/tls.crt"
    tls_key_file: str = "/etc/tls/tls.key"
    drain_delay: float = 5.0
    shutdown_timeout: int = 10
    log_level: str = "INFO"
    # build metadata: read from build_info_file (written at image build), overridable via env/ConfigMap
    build_info_file: str = "/app/build-info.json"
    version: str = "dev"
    commit_sha: str = "unknown"
    build_time: str = "unknown"

    @classmethod
    def from_env(cls) -> "Settings":
        build_info_file = os.getenv("BUILD_INFO_FILE", "/app/build-info.json")
        file_data = _load_build_file(build_info_file)
        return cls(
            port=int(os.getenv("PORT", "8080")),
            tls=_bool("TLS", False),
            tls_cert_file=os.getenv("TLS_CERT_FILE", "/etc/tls/tls.crt"),
            tls_key_file=os.getenv("TLS_KEY_FILE", "/etc/tls/tls.key"),
            drain_delay=float(os.getenv("DRAIN_DELAY_SECONDS", "5")),
            shutdown_timeout=int(os.getenv("SHUTDOWN_TIMEOUT_SECONDS", "10")),
            log_level=os.getenv("LOG_LEVEL", "INFO").upper(),
            build_info_file=build_info_file,
            version=_pick("APP_VERSION", file_data, "version", "dev"),
            commit_sha=_pick("COMMIT_SHA", file_data, "commit_sha", "unknown"),
            build_time=_pick("BUILD_TIME", file_data, "build_time", "unknown"),
        )

    def validate(self) -> None:
        """Fail fast at startup (pod goes CrashLoop with a clear message) instead of serving broken TLS."""
        if self.tls:
            for label, path in (("TLS_CERT_FILE", self.tls_cert_file), ("TLS_KEY_FILE", self.tls_key_file)):
                if not os.path.isfile(path):
                    raise SystemExit(f"TLS=true but {label} does not exist: {path}")
