"""Supabase Auth helpers for the mobile email bridge (anon key only; no admin create/confirm)."""

from __future__ import annotations

import logging

import httpx

from app.core.settings import settings

logger = logging.getLogger(__name__)


class SupabaseAdminAuthError(RuntimeError):
    """Raised for user-facing auth failures. Message must not reveal account existence."""

    pass


class SupabaseEmailConfirmationRequired(SupabaseAdminAuthError):
    """Signup accepted but email confirmation is required before a session is issued."""

    pass


def _jwt_api_key(value: str, label: str) -> str:
    if value.startswith("eyJ"):
        return value
    raise SupabaseAdminAuthError(
        f"Supabase {label} must be a legacy JWT (eyJ...). "
        "Run: python3 backend/scripts/sync_supabase_secrets.py with SUPABASE_ACCESS_TOKEN."
    )


def _anon_headers() -> dict[str, str]:
    if not settings.supabase_url or not settings.supabase_anon_key:
        raise SupabaseAdminAuthError("Supabase anon auth is not configured on the backend")
    anon = _jwt_api_key(settings.supabase_anon_key, "anon key")
    return {
        "apikey": anon,
        "Content-Type": "application/json",
    }


def _extract_error_detail(response: httpx.Response) -> str:
    try:
        payload = response.json()
    except ValueError:
        return response.text.strip() or f"Supabase auth failed ({response.status_code})"
    for key in ("msg", "error_description", "message", "error"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return f"Supabase auth failed ({response.status_code})"


def _safe_auth_failure_message(response: httpx.Response) -> str:
    """Map Supabase errors to messages that avoid account-enumeration leaks."""
    detail = _extract_error_detail(response).lower()
    if response.status_code == 429:
        return "Too many attempts. Please wait and try again."
    if "confirm" in detail or "email not confirmed" in detail:
        return "Email confirmation is required before signing in."
    if response.status_code in (400, 401, 403, 422):
        return "Invalid email or password."
    if response.status_code >= 500:
        return "Authentication service temporarily unavailable."
    return "Unable to complete authentication."


def _session_from_token_payload(payload: dict, fallback_email: str) -> dict[str, str]:
    user = payload.get("user") if isinstance(payload.get("user"), dict) else {}
    user_id = str(payload.get("user_id") or user.get("id") or "").strip()
    access_token = str(payload.get("access_token") or "").strip()
    refresh_token = str(payload.get("refresh_token") or "").strip()
    if not user_id or not access_token or not refresh_token:
        raise SupabaseAdminAuthError("Authentication response incomplete.")
    return {
        "user_id": user_id,
        "email": str(user.get("email") or fallback_email),
        "access_token": access_token,
        "refresh_token": refresh_token,
    }


def password_grant_session(email: str, password: str) -> dict[str, str]:
    """
    Perform a normal Supabase password grant.

    Never creates users, never confirms email, never calls admin APIs.
    """
    base = settings.supabase_url.rstrip("/")
    headers = _anon_headers()
    with httpx.Client(timeout=20.0) as client:
        token = client.post(
            f"{base}/auth/v1/token",
            params={"grant_type": "password"},
            headers=headers,
            json={"email": email, "password": password},
        )
        if token.status_code not in (200, 201):
            logger.info("supabase_password_grant_failed status=%s", token.status_code)
            raise SupabaseAdminAuthError(_safe_auth_failure_message(token))
        payload = token.json()
    return _session_from_token_payload(payload, fallback_email=email)


def signup_with_password(email: str, password: str) -> dict[str, str]:
    """
    Perform a normal Supabase signup (respects project email-confirmation policy).

    Never uses admin create/confirm. Existing accounts cannot be overwritten here.
    """
    base = settings.supabase_url.rstrip("/")
    headers = _anon_headers()
    with httpx.Client(timeout=20.0) as client:
        response = client.post(
            f"{base}/auth/v1/signup",
            headers=headers,
            json={"email": email, "password": password},
        )
        if response.status_code not in (200, 201):
            logger.info("supabase_signup_failed status=%s", response.status_code)
            # Avoid revealing whether the email already exists.
            raise SupabaseAdminAuthError(_safe_auth_failure_message(response))
        payload = response.json()

    # Signup may return a user without a session when email confirmation is required.
    access_token = str(payload.get("access_token") or "").strip()
    refresh_token = str(payload.get("refresh_token") or "").strip()
    user = payload.get("user") if isinstance(payload.get("user"), dict) else {}
    if not access_token or not refresh_token:
        logger.info("supabase_signup_confirmation_required")
        raise SupabaseEmailConfirmationRequired(
            "Check your email to confirm your account before signing in."
        )
    # Defense: if identities empty / confirmed_at missing, still require confirmation.
    confirmed_at = user.get("email_confirmed_at") or user.get("confirmed_at")
    if user and confirmed_at is None and not access_token:
        raise SupabaseEmailConfirmationRequired(
            "Check your email to confirm your account before signing in."
        )
    return _session_from_token_payload(payload, fallback_email=email)


# Backward-compatible name used by older imports/tests — login only, no admin create.
def issue_supabase_password_session(email: str, password: str) -> dict[str, str]:
    return password_grant_session(email=email, password=password)
