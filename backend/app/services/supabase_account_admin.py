"""Supabase admin helpers for account deletion (service role)."""

from __future__ import annotations

import logging
from typing import Any

import httpx

from app.core.settings import settings

logger = logging.getLogger(__name__)

_HTTP_TIMEOUT_SECONDS = 20.0


class SupabaseAdminConfigError(RuntimeError):
    pass


def uses_supabase_auth() -> bool:
    return settings.hiair_auth_provider.strip().lower() == "supabase"


def supabase_admin_configured() -> bool:
    return bool(settings.supabase_url.strip() and settings.supabase_service_role_key.strip())


def require_supabase_admin_config() -> None:
    if not uses_supabase_auth():
        return
    if not supabase_admin_configured():
        raise SupabaseAdminConfigError(
            "Supabase admin credentials are required when HIAIR_AUTH_PROVIDER=supabase."
        )


def _admin_headers() -> dict[str, str]:
    require_supabase_admin_config()
    service = settings.supabase_service_role_key.strip()
    return {
        "apikey": service,
        "Authorization": f"Bearer {service}",
    }


def fetch_auth_user(user_id: str) -> dict[str, Any] | None:
    if not supabase_admin_configured():
        return None
    url = f"{settings.supabase_url.rstrip('/')}/auth/v1/admin/users/{user_id}"
    with httpx.Client(timeout=_HTTP_TIMEOUT_SECONDS) as client:
        response = client.get(url, headers=_admin_headers())
    if response.status_code == 404:
        return None
    if response.status_code >= 400:
        logger.info("supabase_admin_fetch_user_failed status=%s", response.status_code)
        raise SupabaseAdminConfigError(
            f"Supabase admin user lookup failed with status {response.status_code}."
        )
    payload = response.json()
    return payload if isinstance(payload, dict) else None


def detect_auth_provider(user_id: str) -> str:
    user = fetch_auth_user(user_id)
    if not user:
        return "unknown"
    identities = user.get("identities")
    if isinstance(identities, list):
        for identity in identities:
            if not isinstance(identity, dict):
                continue
            provider = str(identity.get("provider") or "").strip().lower()
            if provider == "apple":
                return "apple"
            if provider == "google":
                return "google"
            if provider in {"email", "password"}:
                return "email"
    app_meta = user.get("app_metadata")
    if isinstance(app_meta, dict):
        provider = str(app_meta.get("provider") or "").strip().lower()
        if provider:
            return provider
    return "email"


def delete_auth_user(user_id: str) -> bool:
    """Delete auth.users row. Returns True when deleted, False when already absent."""
    require_supabase_admin_config()
    url = f"{settings.supabase_url.rstrip('/')}/auth/v1/admin/users/{user_id}"
    with httpx.Client(timeout=_HTTP_TIMEOUT_SECONDS) as client:
        response = client.delete(url, headers=_admin_headers())
    if response.status_code in (200, 204):
        return True
    if response.status_code == 404:
        return False
    logger.info("supabase_admin_delete_user_failed status=%s", response.status_code)
    raise SupabaseAdminConfigError(
        f"Supabase admin user deletion failed with status {response.status_code}."
    )
