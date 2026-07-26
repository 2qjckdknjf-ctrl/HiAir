"""Mobile-friendly Supabase email sessions (password grant / signup only; no admin create)."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request

from app.core.settings import settings
from app.models.user import AuthResponse, LoginRequest, SignupRequest
from app.services.request_rate_limiter import check_limit
from app.services.security import validate_password_policy
from app.services.supabase_admin_auth import (
    SupabaseAdminAuthError,
    SupabaseEmailConfirmationRequired,
    password_grant_session,
    signup_with_password,
)

router = APIRouter(prefix="/auth/supabase", tags=["auth"])


def _ensure_bridge_enabled() -> None:
    if not settings.hiair_auth_email_bridge_enabled:
        raise HTTPException(status_code=404, detail="Supabase email bridge is disabled")
    if settings.hiair_auth_provider != "supabase" or not settings.supabase_url:
        raise HTTPException(status_code=503, detail="Supabase auth is not configured")
    if not settings.supabase_anon_key:
        raise HTTPException(status_code=503, detail="Supabase anon key is not configured")


def _rate_limit_email(normalized_email: str) -> None:
    # Per-email guard only; shared carrier/NAT IPs must not block TestFlight sign-in.
    if not check_limit(f"supabase-bridge-email:{normalized_email}", limit=12, window_seconds=900):
        raise HTTPException(
            status_code=429,
            detail="Too many sign-in attempts for this email. Wait 15 minutes and try again.",
        )


@router.post("/session", response_model=AuthResponse)
def supabase_email_session(payload: LoginRequest, request: Request) -> AuthResponse:
    """Password grant only — never creates or auto-confirms users."""
    _ensure_bridge_enabled()
    normalized_email = str(payload.email).strip().lower()
    _ = request.client.host if request.client else "unknown"
    _rate_limit_email(normalized_email)
    is_valid, reason = validate_password_policy(payload.password)
    if not is_valid:
        raise HTTPException(status_code=422, detail=reason)
    try:
        session = password_grant_session(
            email=normalized_email,
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
    """Explicit signup via Supabase signup API (respects email confirmation policy)."""
    _ensure_bridge_enabled()
    normalized_email = str(payload.email).strip().lower()
    _ = request.client.host if request.client else "unknown"
    _rate_limit_email(normalized_email)
    is_valid, reason = validate_password_policy(payload.password)
    if not is_valid:
        raise HTTPException(status_code=422, detail=reason)
    try:
        session = signup_with_password(
            email=normalized_email,
            password=payload.password,
        )
    except (SupabaseEmailConfirmationRequired, SupabaseAdminAuthError) as exc:
        # Same status/message for confirmation-required and other signup failures
        # so responses cannot enumerate account existence or confirmation state.
        # No session is issued in either case.
        status = 429 if "Too many attempts" in str(exc) else 400
        if "temporarily unavailable" in str(exc).lower():
            status = 503
        raise HTTPException(status_code=status, detail=str(exc)) from exc
    return AuthResponse(
        user_id=session["user_id"],
        access_token=session["access_token"],
        refresh_token=session["refresh_token"],
    )
