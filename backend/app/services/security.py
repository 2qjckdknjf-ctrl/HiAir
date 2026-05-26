import hashlib
import secrets
from datetime import UTC, datetime, timedelta
import re

import jwt

from app.core.settings import settings


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    rounds = 100_000
    derived = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        rounds,
    )
    return f"pbkdf2_sha256${rounds}${salt}${derived.hex()}"


def verify_password(password: str, encoded_hash: str) -> bool:
    if isinstance(encoded_hash, (bytes, bytearray)):
        encoded_hash = encoded_hash.decode("utf-8")
    try:
        algo, rounds_str, salt, expected = encoded_hash.split("$", maxsplit=3)
    except ValueError:
        return False
    if algo != "pbkdf2_sha256":
        return False
    try:
        rounds = int(rounds_str)
    except ValueError:
        return False
    derived = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        rounds,
    ).hex()
    return secrets.compare_digest(derived, expected)


def create_access_token(user_id: str) -> str:
    issued_at = datetime.now(tz=UTC)
    expires_at = issued_at + timedelta(minutes=settings.access_token_ttl_minutes)
    payload = {
        "sub": user_id,
        "typ": "access",
        "jti": secrets.token_hex(16),
        "iat": int(issued_at.timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_refresh_token() -> tuple[str, datetime]:
    issued_at = datetime.now(tz=UTC)
    expires_at = issued_at + timedelta(days=settings.refresh_token_ttl_days)
    token = secrets.token_urlsafe(48)
    return token, expires_at


def decode_access_token(token: str) -> str | None:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
        )
    except jwt.PyJWTError:
        return None
    subject = payload.get("sub")
    token_type = payload.get("typ")
    if token_type and token_type != "access":
        return None
    if not isinstance(subject, str) or not subject:
        return None
    return subject


def validate_password_policy(password: str) -> tuple[bool, str]:
    if len(password) < 12:
        return False, "Password must be at least 12 characters long."
    if not re.search(r"[A-Z]", password):
        return False, "Password must include at least one uppercase letter."
    if not re.search(r"[a-z]", password):
        return False, "Password must include at least one lowercase letter."
    if not re.search(r"\d", password):
        return False, "Password must include at least one digit."
    if not re.search(r"[^A-Za-z0-9]", password):
        return False, "Password must include at least one special character."
    return True, ""
