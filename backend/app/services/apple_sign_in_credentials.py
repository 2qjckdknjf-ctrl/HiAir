"""Secure Apple Sign-In credential material for server-side token revocation."""

from __future__ import annotations

import base64
import binascii
import logging
import os
import tempfile
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from app.core.settings import settings

logger = logging.getLogger(__name__)


class AppleSignInConfigError(RuntimeError):
    pass


def apple_sign_in_configured() -> bool:
    return bool(_resolve_p8_material())


def require_apple_sign_in_config() -> None:
    if not apple_sign_in_configured():
        raise AppleSignInConfigError(
            "Apple Sign-In server credentials are not configured "
            "(set APPLE_SIGN_IN_P8_CONTENT or APPLE_SIGN_IN_P8_PATH)."
        )


def _resolve_p8_material() -> str:
    content = (getattr(settings, "apple_sign_in_p8_content", "") or "").strip()
    if content:
        try:
            decoded = base64.b64decode(content, validate=True)
        except (binascii.Error, ValueError) as exc:
            raise AppleSignInConfigError("APPLE_SIGN_IN_P8_CONTENT is not valid base64.") from exc
        pem = decoded.decode("utf-8").strip()
        if "BEGIN PRIVATE KEY" not in pem:
            raise AppleSignInConfigError("APPLE_SIGN_IN_P8_CONTENT must decode to a PEM private key.")
        return pem

    configured_path = (getattr(settings, "apple_sign_in_p8_path", "") or "").strip()
    if configured_path:
        path = Path(configured_path)
        if not path.is_file():
            raise AppleSignInConfigError(f"APPLE_SIGN_IN_P8_PATH does not exist: {configured_path}")
        return path.read_text(encoding="utf-8").strip()
    return ""


@contextmanager
def temporary_apple_p8_path() -> Iterator[Path]:
    """Write PEM to a private temp file for libraries that require a path."""
    pem = _resolve_p8_material()
    if not pem:
        raise AppleSignInConfigError("Apple Sign-In private key is not configured.")

    fd, raw_path = tempfile.mkstemp(prefix="hiair-apple-p8-", suffix=".p8")
    path = Path(raw_path)
    try:
        os.write(fd, pem.encode("utf-8"))
        os.close(fd)
        os.chmod(path, 0o600)
        yield path
    finally:
        try:
            path.unlink(missing_ok=True)
        except OSError:
            logger.exception("apple_p8_temp_cleanup_failed")
