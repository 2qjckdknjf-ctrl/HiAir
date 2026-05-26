from fastapi import APIRouter, Depends, HTTPException, Request
from psycopg import Error as PsycopgError

from app.api.deps import AuthContext, get_current_auth_context
from app.core.settings import settings
from app.models.user import AuthResponse, LoginRequest, RefreshTokenRequest, SignupRequest
from app.services import auth_guard, auth_tokens_repository
from app.services.request_rate_limiter import check_limit
from app.services.security import create_access_token, create_refresh_token, validate_password_policy
import app.services.subscription_repository as subscription_repository
import app.services.user_repository as user_repository

router = APIRouter(prefix="/auth", tags=["auth"])


def _ensure_legacy_auth_enabled() -> None:
    if (
        settings.hiair_auth_provider == "supabase"
        and settings.supabase_url
        and not settings.hiair_auth_legacy_enabled
    ):
        raise HTTPException(
            status_code=410,
            detail=(
                "Legacy password auth endpoints are disabled. "
                "Use Supabase Auth on client and send Supabase bearer token."
            ),
        )


@router.post("/signup", response_model=AuthResponse)
def signup(payload: SignupRequest, request: Request) -> AuthResponse:
    _ensure_legacy_auth_enabled()
    client_host = request.client.host if request.client else "unknown"
    if not check_limit(f"signup-ip:{client_host}", limit=10, window_seconds=600):
        raise HTTPException(status_code=429, detail="Too many signup attempts. Please retry later.")
    is_valid, reason = validate_password_policy(payload.password)
    if not is_valid:
        raise HTTPException(status_code=422, detail=reason)
    try:
        user_id = user_repository.create_user(email=payload.email, password=payload.password)
        refresh_token, refresh_expires_at = create_refresh_token()
        auth_tokens_repository.create_refresh_token(
            user_id=user_id,
            refresh_token=refresh_token,
            expires_at=refresh_expires_at,
        )
    except user_repository.UserConflictError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return AuthResponse(
        user_id=user_id,
        access_token=create_access_token(user_id),
        refresh_token=refresh_token,
    )


@router.post("/login", response_model=AuthResponse)
def login(payload: LoginRequest, request: Request) -> AuthResponse:
    _ensure_legacy_auth_enabled()
    client_host = request.client.host if request.client else "unknown"
    if not check_limit(f"login-ip:{client_host}", limit=30, window_seconds=600):
        raise HTTPException(status_code=429, detail="Too many login attempts. Please retry later.")
    if auth_guard.check_login_lock(payload.email):
        raise HTTPException(status_code=429, detail="Account temporarily locked due to failed logins.")
    try:
        user_id = user_repository.verify_user(email=payload.email, password=payload.password)
        auth_guard.clear_login_failures(payload.email)
        refresh_token, refresh_expires_at = create_refresh_token()
        auth_tokens_repository.create_refresh_token(
            user_id=user_id,
            refresh_token=refresh_token,
            expires_at=refresh_expires_at,
        )
    except user_repository.AuthError as exc:
        auth_guard.register_login_failure(payload.email)
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return AuthResponse(
        user_id=user_id,
        access_token=create_access_token(user_id),
        refresh_token=refresh_token,
    )


@router.post("/refresh", response_model=AuthResponse)
def refresh(payload: RefreshTokenRequest, request: Request) -> AuthResponse:
    _ensure_legacy_auth_enabled()
    client_host = request.client.host if request.client else "unknown"
    if not check_limit(f"refresh-ip:{client_host}", limit=60, window_seconds=600):
        raise HTTPException(status_code=429, detail="Too many refresh attempts. Please retry later.")
    try:
        existing = auth_tokens_repository.get_active_refresh_token(payload.refresh_token)
        if existing is None:
            raise HTTPException(status_code=401, detail="Invalid refresh token")
        auth_tokens_repository.revoke_refresh_token(payload.refresh_token)
        new_refresh_token, new_expires_at = create_refresh_token()
        auth_tokens_repository.create_refresh_token(
            user_id=existing["user_id"],
            refresh_token=new_refresh_token,
            expires_at=new_expires_at,
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return AuthResponse(
        user_id=existing["user_id"],
        access_token=create_access_token(existing["user_id"]),
        refresh_token=new_refresh_token,
    )


@router.post("/logout", response_model=dict[str, str])
def logout(payload: RefreshTokenRequest) -> dict[str, str]:
    _ensure_legacy_auth_enabled()
    try:
        auth_tokens_repository.revoke_refresh_token(payload.refresh_token)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return {"status": "ok"}


@router.get("/me", response_model=dict[str, object | None])
def me(auth: AuthContext = Depends(get_current_auth_context)) -> dict[str, object | None]:
    profile: dict[str, object] | None = None
    subscription: dict[str, object | None] | None = None
    try:
        profiles = user_repository.list_profiles(user_id=auth.user_id)
        if profiles:
            first = profiles[0]
            profile = {
                "id": first.id,
                "user_id": first.user_id,
                "persona_type": first.persona_type,
                "sensitivity_level": first.sensitivity_level,
                "home_lat": first.home_lat,
                "home_lon": first.home_lon,
            }
        sub = subscription_repository.get_user_subscription(user_id=auth.user_id)
        subscription = {
            "plan_id": sub.plan_id,
            "status": sub.status,
            "starts_at": sub.starts_at.isoformat() if sub.starts_at else None,
            "current_period_end": sub.current_period_end.isoformat() if sub.current_period_end else None,
            "auto_renew": sub.auto_renew,
        }
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc

    return {
        "user_id": auth.user_id,
        "email": auth.email,
        "profile": profile,
        "subscription": subscription,
        "auth_provider": auth.provider,
    }
