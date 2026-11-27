import json
import logging
from pathlib import Path

from app.services import secret_store
from app.services.secret_redaction import redact_text


def test_redact_text_masks_openai_key_and_bearer() -> None:
    raw = "OPENAI_API_KEY=sk-abcdefghijklmnopqrstuvwxyz Authorization: Bearer eyJhbGciOiJIUzI1NiIs.aaa.bbb"
    cleaned = redact_text(raw)
    assert "sk-abcdefghijklmnopqrstuvwxyz" not in cleaned
    assert "Bearer ***" in cleaned or "bearer ***" in cleaned.lower()
    assert "***" in cleaned


def test_logging_filter_blocks_secret_in_args() -> None:
    from app.services.secret_redaction import install_secret_redaction

    install_secret_redaction(extra_secrets=["super-secret-value-123456"])
    logger = logging.getLogger("hiair.test.secret_redaction.child")
    logger.setLevel(logging.INFO)
    records: list[str] = []

    class Capture(logging.Handler):
        def emit(self, record: logging.LogRecord) -> None:
            records.append(record.getMessage())

    root = logging.getLogger()
    handler = Capture()
    root.addHandler(handler)
    try:
        logger.info("token=%s", "super-secret-value-123456")
        assert records
        rendered = records[-1]
        assert "super-secret-value-123456" not in rendered
        assert "***" in rendered
    finally:
        root.removeHandler(handler)


def test_secret_store_revocation_fail_closed(tmp_path: Path, monkeypatch) -> None:
    secrets_path = tmp_path / "secrets.json"
    secrets_path.write_text(json.dumps({"FCM_SERVER_KEY": "live-secret-aaaaaaaa"}), encoding="utf-8")
    monkeypatch.setattr(
        secret_store,
        "settings",
        type(
            "S",
            (),
            {
                "secret_source": "file",
                "secret_file_path": str(secrets_path),
                "secret_http_url": "",
                "secret_http_token": "",
                "secret_http_timeout_ms": 1000,
                "secret_cache_ttl_seconds": 60,
                "vault_addr": "",
                "vault_token": "",
                "vault_namespace": "",
                "vault_kv_mount": "secret",
                "vault_kv_path": "hiair",
            },
        )(),
    )
    secret_store.refresh_secret_cache()
    assert secret_store.get_secret("FCM_SERVER_KEY") == "live-secret-aaaaaaaa"

    # Rotate/revoke: empty file → cache refresh must fail closed to empty.
    secrets_path.write_text("{}", encoding="utf-8")
    secret_store.refresh_secret_cache()
    assert secret_store.get_secret("FCM_SERVER_KEY", env_fallback="") == ""
