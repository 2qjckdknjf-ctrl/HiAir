from fastapi import Header, HTTPException
from psycopg import Error as PsycopgError

from app.core.settings import settings
from app.services.security import decode_access_token
import app.services.user_repository as user_repository


def get_current_user_id(
    authorization: str | None = Header(default=None),
    x_user_id: str | None = Header(default=None),
) -> str:
    if authorization:
        scheme, _, token = authorization.partition(" ")
        if scheme.lower() != "bearer" or not token:
            raise HTTPException(status_code=401, detail="Invalid Authorization header")
        user_id = decode_access_token(token)
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid or expired token")
        try:
            if not user_repository.user_exists(user_id):
                raise HTTPException(status_code=401, detail="User is not available")
        except PsycopgError as exc:
            raise HTTPException(status_code=503, detail="Database unavailable") from exc
        return user_id
    if x_user_id and settings.allow_legacy_user_header_auth:
        # Temporary migration mode for legacy clients.
        try:
            if not user_repository.user_exists(x_user_id):
                raise HTTPException(status_code=401, detail="User is not available")
        except PsycopgError as exc:
            raise HTTPException(status_code=503, detail="Database unavailable") from exc
        return x_user_id
    raise HTTPException(status_code=401, detail="Missing authentication header")


def require_ops_admin_token(x_admin_token: str | None = Header(default=None)) -> bool:
    if not settings.notification_admin_token:
        return True
    if x_admin_token != settings.notification_admin_token:
        raise HTTPException(status_code=403, detail="Forbidden")
    return True
