import pytest
from fastapi.testclient import TestClient

from config import Settings
from main import app, build_uvicorn_config, state

client = TestClient(app)


def test_build_info_fields():
    r = client.get("/api/v1/build-info")
    assert r.status_code == 200
    assert {"version", "commit_sha", "build_time", "python_version"} <= r.json().keys()


def test_liveness():
    assert client.get("/healthz").status_code == 200


def test_readiness_ok_then_fails_on_shutdown():
    state.shutting_down = False
    assert client.get("/readyz").status_code == 200
    state.shutting_down = True
    assert client.get("/readyz").status_code == 503
    state.shutting_down = False


def test_liveness_unaffected_by_shutdown():
    state.shutting_down = True
    assert client.get("/healthz").status_code == 200
    state.shutting_down = False


# ---- configuration ----
def test_settings_from_env(monkeypatch):
    monkeypatch.setenv("TLS", "true")
    monkeypatch.setenv("TLS_CERT_FILE", "/x/c.crt")
    monkeypatch.setenv("TLS_KEY_FILE", "/x/c.key")
    monkeypatch.setenv("PORT", "9443")
    s = Settings.from_env()
    assert s.tls and s.port == 9443 and s.tls_cert_file == "/x/c.crt"


def test_tls_false_has_no_ssl_args():
    cfg = build_uvicorn_config(Settings(tls=False))
    assert cfg.ssl_certfile is None


def test_tls_true_passes_cert_paths():
    cfg = build_uvicorn_config(Settings(tls=True, tls_cert_file="/a.crt", tls_key_file="/a.key"))
    assert cfg.ssl_certfile == "/a.crt" and cfg.ssl_keyfile == "/a.key"


def test_validate_fails_fast_when_cert_missing():
    with pytest.raises(SystemExit):
        Settings(tls=True, tls_cert_file="/nope.crt", tls_key_file="/nope.key").validate()


def test_validate_ok_when_tls_off():
    Settings(tls=False).validate()


# ---- build metadata: file < env override ----
import json


def _write_build_file(tmp_path, **kw):
    f = tmp_path / "build-info.json"
    f.write_text(json.dumps(kw))
    return str(f)


def _clear(monkeypatch):
    for k in ("APP_VERSION", "COMMIT_SHA", "BUILD_TIME", "BUILD_INFO_FILE"):
        monkeypatch.delenv(k, raising=False)


def test_build_info_read_from_file(tmp_path, monkeypatch):
    _clear(monkeypatch)
    monkeypatch.setenv("BUILD_INFO_FILE", _write_build_file(tmp_path, version="1.2.3", commit_sha="abc", build_time="t"))
    s = Settings.from_env()
    assert (s.version, s.commit_sha, s.build_time) == ("1.2.3", "abc", "t")


def test_env_overrides_file(tmp_path, monkeypatch):
    _clear(monkeypatch)
    monkeypatch.setenv("BUILD_INFO_FILE", _write_build_file(tmp_path, version="1.2.3", commit_sha="abc", build_time="t"))
    monkeypatch.setenv("APP_VERSION", "9.9.9")           # as if set from the ConfigMap
    s = Settings.from_env()
    assert s.version == "9.9.9" and s.commit_sha == "abc"   # only the overridden field changes


def test_missing_file_falls_back_to_defaults(tmp_path, monkeypatch):
    _clear(monkeypatch)
    monkeypatch.setenv("BUILD_INFO_FILE", str(tmp_path / "nope.json"))
    s = Settings.from_env()
    assert (s.version, s.commit_sha) == ("dev", "unknown")


def test_invalid_file_falls_back_to_defaults(tmp_path, monkeypatch):
    _clear(monkeypatch)
    bad = tmp_path / "bad.json"
    bad.write_text("not json")
    monkeypatch.setenv("BUILD_INFO_FILE", str(bad))
    assert Settings.from_env().version == "dev"


def test_empty_env_value_does_not_override(tmp_path, monkeypatch):
    _clear(monkeypatch)
    monkeypatch.setenv("BUILD_INFO_FILE", _write_build_file(tmp_path, version="1.2.3"))
    monkeypatch.setenv("APP_VERSION", "")
    assert Settings.from_env().version == "1.2.3"
