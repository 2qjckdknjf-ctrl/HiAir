"""Redact secrets from log records before they reach handlers."""

from __future__ import annotations

import logging
import re
from typing import Iterable

_SECRET_ENV_KEYS = (
    "OPENAI_API_KEY",
    "SUPABASE_SERVICE_ROLE_KEY",
    "SUPABASE_ANON_KEY",
    "SUPABASE_JWT_SECRET",
    "JWT_SECRET",
    "WEATHER_API_KEY",
    "AQI_API_KEY",
    "AMBEE_API_KEY",
    "FCM_SERVER_KEY",
    "FCM_PRIVATE_KEY",
    "APNS_AUTH_TOKEN",
    "APNS_PRIVATE_KEY",
    "SUBSCRIPTION_WEBHOOK_SECRET",
    "NOTIFICATION_ADMIN_TOKEN",
    "VAULT_TOKEN",
    "SECRET_HTTP_TOKEN",
)

_BEARER_RE = re.compile(r"(?i)(bearer\s+)([A-Za-z0-9._\-]+)")
_ASSIGN_RE = re.compile(
    r"(?i)\b("
    + "|".join(re.escape(key) for key in _SECRET_ENV_KEYS)
    + r")\b(\s*[=:]\s*)([^\s,;]+)"
)
_SK_RE = re.compile(r"\b(sk-[A-Za-z0-9]{8,})\b")
_JWTish_RE = re.compile(r"\beyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\b")

_installed = False
_extra_secrets: tuple[str, ...] = ()
_original_factory = logging.getLogRecordFactory()


def redact_text(text: str, extra_secrets: Iterable[str] | None = None) -> str:
    """Return ``text`` with known secret patterns replaced by ``***``."""
    if not text:
        return text
    redacted = _BEARER_RE.sub(r"\1***", text)
    redacted = _ASSIGN_RE.sub(r"\1\2***", redacted)
    redacted = _SK_RE.sub("***", redacted)
    redacted = _JWTish_RE.sub("***", redacted)
    for secret in extra_secrets or ():
        value = (secret or "").strip()
        if len(value) >= 8 and value in redacted:
            redacted = redacted.replace(value, "***")
    return redacted


def _redact_record(record: logging.LogRecord) -> logging.LogRecord:
    try:
        if isinstance(record.msg, str):
            record.msg = redact_text(record.msg, _extra_secrets)
        if record.args:
            if isinstance(record.args, dict):
                record.args = {
                    key: redact_text(str(value), _extra_secrets) if isinstance(value, str) else value
                    for key, value in record.args.items()
                }
            elif isinstance(record.args, tuple):
                record.args = tuple(
                    redact_text(arg, _extra_secrets) if isinstance(arg, str) else arg
                    for arg in record.args
                )
    except Exception:
        return record
    return record


class SecretRedactionFilter(logging.Filter):
    """Logging filter that scrubs secrets from msg and args."""

    def filter(self, record: logging.LogRecord) -> bool:
        _redact_record(record)
        return True


def _record_factory(*args, **kwargs) -> logging.LogRecord:
    record = _original_factory(*args, **kwargs)
    return _redact_record(record)


def install_secret_redaction(extra_secrets: Iterable[str] | None = None) -> SecretRedactionFilter:
    """Install process-wide secret redaction for all loggers/handlers."""
    global _installed, _extra_secrets
    _extra_secrets = tuple(s for s in (extra_secrets or ()) if s)
    filt = SecretRedactionFilter()
    root = logging.getLogger()
    if not any(isinstance(existing, SecretRedactionFilter) for existing in root.filters):
        root.addFilter(filt)
    for handler in root.handlers:
        if not any(isinstance(existing, SecretRedactionFilter) for existing in handler.filters):
            handler.addFilter(filt)
    if not _installed:
        logging.setLogRecordFactory(_record_factory)
        _installed = True
    return filt
