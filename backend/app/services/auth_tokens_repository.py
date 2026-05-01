import hashlib
from datetime import UTC, datetime
from uuid import uuid4

from app.services.db import get_connection


def create_refresh_token(user_id: str, refresh_token: str, expires_at: datetime) -> None:
    token_id = str(uuid4())
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO auth_refresh_tokens (id, user_id, token_hash, expires_at)
                VALUES (%s, %s, %s, %s)
                """,
                (token_id, user_id, _hash_refresh_token(refresh_token), expires_at),
            )


def get_active_refresh_token(refresh_token: str) -> dict | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, user_id, expires_at, revoked_at
                FROM auth_refresh_tokens
                WHERE token_hash = %s
                LIMIT 1
                """,
                (_hash_refresh_token(refresh_token),),
            )
            row = cur.fetchone()
    if row is None:
        return None
    if row["revoked_at"] is not None:
        return None
    expires_at = row["expires_at"]
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=UTC)
    if expires_at <= datetime.now(tz=UTC):
        return None
    return row


def revoke_refresh_token(refresh_token: str) -> bool:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE auth_refresh_tokens
                SET revoked_at = NOW()
                WHERE token_hash = %s
                  AND revoked_at IS NULL
                """,
                (_hash_refresh_token(refresh_token),),
            )
            return cur.rowcount > 0


def _hash_refresh_token(refresh_token: str) -> str:
    return hashlib.sha256(refresh_token.encode("utf-8")).hexdigest()
