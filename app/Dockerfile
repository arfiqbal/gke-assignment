# syntax=docker/dockerfile:1.7
ARG PYTHON_VERSION=3.12

# ---------- Stage 1: resolve and install dependencies with uv ----------
FROM python:${PYTHON_VERSION}-slim AS builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
RUN pip install --no-cache-dir uv==0.11.32
WORKDIR /app
# deps first (layer cache): only re-runs when pyproject/uv.lock change
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

# ---------- Stage 2: gsutil client (isolated venv, copied into the runtime image) ----------
# Only the client is installed; no commands are run and no credentials are baked in.
# At runtime gsutil authenticates through the pod's Workload Identity (GKE metadata server).
# Same base image + Python version as the runtime stage, so the venv works after COPY.
FROM python:${PYTHON_VERSION}-slim AS gsutil
ARG GSUTIL_VERSION=5.38
ENV UV_LINK_MODE=copy
RUN pip install --no-cache-dir uv==0.11.32
RUN uv venv /opt/gsutil --python "$(which python)" && \
    VIRTUAL_ENV=/opt/gsutil uv pip install --no-cache "gsutil==${GSUTIL_VERSION}"

# ---------- Stage 3: runtime ----------
FROM python:${PYTHON_VERSION}-slim
ENV PATH="/app/.venv/bin:$PATH" HOME=/tmp PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY --from=gsutil /opt/gsutil /opt/gsutil
RUN ln -s /opt/gsutil/bin/gsutil /usr/local/bin/gsutil
COPY src/ .

# Build metadata is written to a file (not ENV) so a ConfigMap/env var can override it at runtime.
# Declared last so changing COMMIT_SHA/BUILD_TIME only invalidates this tiny layer, not the dependency layers.
ARG APP_VERSION=dev
ARG COMMIT_SHA=unknown
ARG BUILD_TIME=unknown
RUN python -c 'import json,sys; json.dump(dict(version=sys.argv[1], commit_sha=sys.argv[2], build_time=sys.argv[3]), open("/app/build-info.json","w"))' \
      "${APP_VERSION}" "${COMMIT_SHA}" "${BUILD_TIME}" && chmod 644 /app/build-info.json
USER 10001
# Documentation only (does not publish ports). Actual port is set by PORT: 8080 = HTTP default, 8443 = HTTPS (TLS=true)
EXPOSE 8080 8443
# exec form: python is PID 1 and receives SIGTERM directly
ENTRYPOINT ["python", "main.py"]
