# build-info service

| Endpoint | Purpose |
|---|---|
| `GET /api/v1/build-info` | version, commit_sha, build_time, python_version |
| `GET /healthz` | liveness (always 200 while process is up) |
| `GET /readyz` | readiness (503 once SIGTERM received) |

## Configuration (env vars, supplied by `deploy/k8s/configmap.yaml`)

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8080` | listen port |
| `TLS` | `false` | `true` = HTTPS, `false` = HTTP |
| `TLS_CERT_FILE` | `/etc/tls/tls.crt` | certificate path (required when TLS=true) |
| `TLS_KEY_FILE` | `/etc/tls/tls.key` | private key path (required when TLS=true) |
| `DRAIN_DELAY_SECONDS` | `5` | readiness fails this long before listeners stop |
| `SHUTDOWN_TIMEOUT_SECONDS` | `10` | max wait for in-flight requests |
| `LOG_LEVEL` | `INFO` | log level |
| `BUILD_INFO_FILE` | `/app/build-info.json` | file written at image build holding version/commit/build time |
| `APP_VERSION` / `COMMIT_SHA` / `BUILD_TIME` | _(unset)_ | optional overrides; **env var > build file > default** |

With `TLS=true` the app exits at startup if the cert or key file is missing.

## Local development (uv)
    uv sync                 # create .venv from uv.lock
    uv run pytest
    uv run python src/main.py                                  # HTTP on :8080
    TLS=true TLS_CERT_FILE=./my.crt TLS_KEY_FILE=./my.key PORT=8443 uv run python src/main.py

Self-signed cert for testing:
    openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=localhost" -keyout my.key -out my.crt

## Build image
    DOCKER_BUILDKIT=1 docker build -t build-info \
      --build-arg APP_VERSION=1.0.0 \
      --build-arg COMMIT_SHA=$(git rev-parse --short HEAD) \
      --build-arg BUILD_TIME=$(date -u +%FT%TZ) .

The image includes the `gsutil` client (isolated venv at `/opt/gsutil`, linked to `/usr/local/bin/gsutil`).
No credentials are baked in; at runtime it uses the pod's Workload Identity.
The service account bound to the pod needs a role on the bucket, e.g. `roles/storage.objectViewer`.
    kubectl exec -n build-info deploy/build-info -- gsutil ls gs://my-bucket

## Deploy
    kubectl create secret tls build-info-tls -n build-info --cert=my.crt --key=my.key
    kubectl apply -f deploy/k8s/configmap.yaml -f deploy/k8s/deployment.yaml

To run plain HTTP instead: set `TLS: "false"` and `PORT` in the ConfigMap, and change probe `scheme` to `HTTP` in the Deployment.

## Test graceful shutdown
    kubectl rollout restart deployment/build-info -n build-info   # while running hey/k6 load
