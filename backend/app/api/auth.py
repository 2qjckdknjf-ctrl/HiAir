from fastapi import APIRouter, Depends, HTTPException, Request
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.user import AuthResponse, LoginRequest, RefreshTokenRequest, SignupRequest
from app.services import auth_guard, auth_tokens_repository
from app.services.security import create_access_token, create_refresh_token, validate_password_policy
import app.services.user_repository as user_repository

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=AuthResponse)
def signup(payload: SignupRequest, request: Request) -> AuthResponse:
    client_host = request.client.host if request.client else "unknown"
    if auth_guard.is_rate_limited(f"signup-ip:{client_host}", limit=10, window_seconds=600):
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
    client_host = request.client.host if request.client else "unknown"
    if auth_guard.is_rate_limited(f"login-ip:{client_host}", limit=30, window_seconds=600):
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
def refresh(payload: RefreshTokenRequest) -> AuthResponse:
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
    try:
        auth_tokens_repository.revoke_refresh_token(payload.refresh_token)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return {"status": "ok"}


@router.get("/me", response_model=dict[str, str])
def me(user_id: str = Depends(get_current_user_id)) -> dict[str, str]:
    return {"user_id": user_id}
