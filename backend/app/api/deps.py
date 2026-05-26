from dataclasses import dataclass
from typing import Any

from fastapi import Depends, Header, HTTPException
from psycopg import Error as PsycopgError

from app.core.settings import _is_protected_env, settings
from app.services.security import decode_access_token
from app.services.supabase_auth import SupabaseAuthError, verify_supabase_access_token
import app.services.user_repository as user_repository


@dataclass(frozen=True)
class AuthContext:
    user_id: str
    email: str | None = None
    provider: str = "unknown"
    claims: dict[str, Any] | None = None


def _extract_bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing authentication header")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="Invalid Authorization header")
    return token


def _resolve_supabase_context(token: str) -> AuthContext:
    try:
        principal = verify_supabase_access_token(token)
    except SupabaseAuthError as exc:
        raise HTTPException(status_code=401, detail=f"Invalid Supabase token: {exc}") from exc
    return AuthContext(
        user_id=principal.user_id,
        email=principal.email,
        provider="supabase",
        claims=principal.claims,
    )


def _resolve_legacy_context(token: str) -> AuthContext:
    user_id = decode_access_token(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    try:
        if not user_repository.user_exists(user_id):
            raise HTTPException(status_code=401, detail="User is not available")
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return AuthContext(user_id=user_id, provider="legacy")


def get_current_auth_context(
    authorization: str | None = Header(default=None),
) -> AuthContext:
    token = _extract_bearer_token(authorization)

    if settings.hiair_auth_provider == "supabase":
        # Transitional fallback for local/test environments where Supabase is not wired yet.
        if not settings.supabase_url:
            return _resolve_legacy_context(token)
        try:
            return _resolve_supabase_context(token)
        except HTTPException:
            if not settings.hiair_auth_legacy_enabled:
                raise
            return _resolve_legacy_context(token)

    return _resolve_legacy_context(token)


def get_current_user_id(
    auth_context: AuthContext = Depends(get_current_auth_context),
) -> str:
    return auth_context.user_id


def require_ops_admin_token(x_admin_token: str | None = Header(default=None)) -> bool:
    if not settings.notification_admin_token:
        if settings.allow_insecure_local_dev and not _is_protected_env(settings.app_env):
            return True
        raise HTTPException(status_code=503, detail="Notification admin token is not configured")
    if x_admin_token != settings.notification_admin_token:
        raise HTTPException(status_code=403, detail="Forbidden")
    return True
