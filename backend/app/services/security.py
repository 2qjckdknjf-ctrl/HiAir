import hashlib
import secrets
from datetime import UTC, datetime, timedelta

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
    rounds = int(rounds_str)
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
        "iat": int(issued_at.timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


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
    if not isinstance(subject, str) or not subject:
        return None
    return subject
