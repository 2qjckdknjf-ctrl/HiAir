"""Mobile-friendly Supabase email sessions while dashboard OAuth providers are being enabled."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request

from app.core.settings import settings
from app.models.user import AuthResponse, LoginRequest, SignupRequest
from app.services.request_rate_limiter import check_limit
from app.services.security import validate_password_policy
from app.services.supabase_admin_auth import SupabaseAdminAuthError, issue_supabase_password_session

router = APIRouter(prefix="/auth/supabase", tags=["auth"])


def _ensure_bridge_enabled() -> None:
    if settings.hiair_auth_provider != "supabase" or not settings.supabase_url:
        raise HTTPException(status_code=503, detail="Supabase auth is not configured")
    if not settings.supabase_service_role_key:
        raise HTTPException(status_code=503, detail="Supabase service role is not configured")


@router.post("/session", response_model=AuthResponse)
def supabase_email_session(payload: LoginRequest, request: Request) -> AuthResponse:
    """Return a confirmed Supabase session for email/password (TestFlight unblock)."""
    _ensure_bridge_enabled()
    client_host = request.client.host if request.client else "unknown"
    if not check_limit(f"supabase-bridge-ip:{client_host}", limit=20, window_seconds=600):
        raise HTTPException(status_code=429, detail="Too many auth attempts. Please retry later.")
    is_valid, reason = validate_password_policy(payload.password)
    if not is_valid:
        raise HTTPException(status_code=422, detail=reason)
    try:
        session = issue_supabase_password_session(
            email=str(payload.email).strip().lower(),
            password=payload.password,
        )
    except SupabaseAdminAuthError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return AuthResponse(
        user_id=session["user_id"],
        access_token=session["access_token"],
        refresh_token=session["refresh_token"],
    )


@router.post("/signup", response_model=AuthResponse)
def supabase_email_signup(payload: SignupRequest, request: Request) -> AuthResponse:
    return supabase_email_session(
        LoginRequest(email=payload.email, password=payload.password),
        request,
    )
