"""Supabase Auth admin helpers (service role) for TestFlight email bridge."""

from __future__ import annotations

import httpx

from app.core.settings import settings


class SupabaseAdminAuthError(RuntimeError):
    pass


def _jwt_api_key(value: str, label: str) -> str:
    if value.startswith("eyJ"):
        return value
    raise SupabaseAdminAuthError(
        f"Supabase {label} must be a legacy JWT (eyJ...). "
        "Run: python3 backend/scripts/sync_supabase_secrets.py with SUPABASE_ACCESS_TOKEN."
    )


def _admin_headers() -> dict[str, str]:
    if not settings.supabase_url or not settings.supabase_service_role_key:
        raise SupabaseAdminAuthError("Supabase service role is not configured on the backend")
    service_role = _jwt_api_key(settings.supabase_service_role_key, "service role key")
    anon = _jwt_api_key(
        settings.supabase_anon_key or settings.supabase_service_role_key,
        "anon key",
    )
    return {
        "Authorization": f"Bearer {service_role}",
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


def issue_supabase_password_session(email: str, password: str) -> dict[str, str]:
    """Create (or reuse) a confirmed Supabase user and return password grant tokens."""
    base = settings.supabase_url.rstrip("/")
    headers = _admin_headers()
    with httpx.Client(timeout=20.0) as client:
        create = client.post(
            f"{base}/auth/v1/admin/users",
            headers=headers,
            json={
                "email": email,
                "password": password,
                "email_confirm": True,
            },
        )
        if create.status_code not in (200, 201, 422):
            raise SupabaseAdminAuthError(_extract_error_detail(create))

        token_headers = {
            "apikey": _jwt_api_key(
                settings.supabase_anon_key or settings.supabase_service_role_key,
                "anon key",
            ),
            "Content-Type": "application/json",
        }
        token = client.post(
            f"{base}/auth/v1/token",
            params={"grant_type": "password"},
            headers=token_headers,
            json={"email": email, "password": password},
        )
        if token.status_code not in (200, 201):
            raise SupabaseAdminAuthError(_extract_error_detail(token))
        payload = token.json()
    user = payload.get("user") if isinstance(payload.get("user"), dict) else {}
    user_id = str(payload.get("user_id") or user.get("id") or "").strip()
    access_token = str(payload.get("access_token") or "").strip()
    refresh_token = str(payload.get("refresh_token") or "").strip()
    if not user_id or not access_token or not refresh_token:
        raise SupabaseAdminAuthError("Supabase token response missing session fields")
    return {
        "user_id": user_id,
        "email": str(user.get("email") or email),
        "access_token": access_token,
        "refresh_token": refresh_token,
    }
