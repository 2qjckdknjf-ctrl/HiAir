"""Security regression tests for Supabase email auth bridge (no admin create/confirm)."""

from __future__ import annotations

from dataclasses import replace

import httpx
from fastapi.testclient import TestClient

from app.core import settings as settings_module
from app.main import app
from app.services import supabase_admin_auth as auth_svc


def _patch_settings(monkeypatch, **kwargs):
    cfg = replace(settings_module.settings, **kwargs)
    monkeypatch.setattr(settings_module, "settings", cfg)
    monkeypatch.setattr("app.api.auth_supabase_bridge.settings", cfg)
    monkeypatch.setattr(auth_svc, "settings", cfg)


class _FakeResponse:
    def __init__(self, status_code: int, payload: dict | None = None, text: str = ""):
        self.status_code = status_code
        self._payload = payload or {}
        self.text = text or json_dumps(payload)

    def json(self):
        return self._payload


def json_dumps(payload: dict | None) -> str:
    import json

    return json.dumps(payload or {})


class _FakeClient:
    def __init__(self, handler):
        self._handler = handler
        self.calls: list[tuple[str, str, dict | None]] = []

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def post(self, url, *, params=None, headers=None, json=None):  # noqa: A002
        path = url
        self.calls.append((path, (params or {}).get("grant_type"), json))
        return self._handler(path, params=params, headers=headers, json=json)


def test_session_never_calls_admin_create(monkeypatch) -> None:
    _patch_settings(
        monkeypatch,
        hiair_auth_email_bridge_enabled=True,
        hiair_auth_provider="supabase",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.anon",
        supabase_service_role_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.service",
    )

    def handler(url, params=None, headers=None, json=None):  # noqa: A002
        assert "/admin/users" not in url
        assert params and params.get("grant_type") == "password"
        assert "email_confirm" not in (json or {})
        return _FakeResponse(
            200,
            {
                "user_id": "11111111-1111-1111-1111-111111111111",
                "access_token": "access",
                "refresh_token": "refresh",
                "user": {"id": "11111111-1111-1111-1111-111111111111", "email": "user@example.com"},
            },
        )

    fake = _FakeClient(handler)
    monkeypatch.setattr(httpx, "Client", lambda timeout=20.0: fake)

    client = TestClient(app)
    response = client.post(
        "/api/auth/supabase/session",
        json={"email": "user@example.com", "password": "ValidPass123!"},
    )
    assert response.status_code == 200
    assert all("/admin/users" not in call[0] for call in fake.calls)
    assert any(call[1] == "password" for call in fake.calls)


def test_login_unknown_email_does_not_create_user(monkeypatch) -> None:
    _patch_settings(
        monkeypatch,
        hiair_auth_email_bridge_enabled=True,
        hiair_auth_provider="supabase",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.anon",
    )
    created = {"admin": False}

    def handler(url, params=None, headers=None, json=None):  # noqa: A002
        if "/admin/users" in url:
            created["admin"] = True
            return _FakeResponse(201, {"id": "new"})
        return _FakeResponse(400, {"error_description": "Invalid login credentials"})

    fake = _FakeClient(handler)
    monkeypatch.setattr(httpx, "Client", lambda timeout=20.0: fake)

    client = TestClient(app)
    response = client.post(
        "/api/auth/supabase/session",
        json={"email": "unknown@example.com", "password": "ValidPass123!"},
    )
    assert response.status_code == 400
    assert created["admin"] is False
    assert "Invalid email or password" in response.json()["detail"]


def test_signup_and_signin_are_separated(monkeypatch) -> None:
    _patch_settings(
        monkeypatch,
        hiair_auth_email_bridge_enabled=True,
        hiair_auth_provider="supabase",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.anon",
    )
    seen = {"signup": 0, "token": 0}

    def handler(url, params=None, headers=None, json=None):  # noqa: A002
        if url.endswith("/auth/v1/signup"):
            seen["signup"] += 1
            return _FakeResponse(
                200,
                {
                    "access_token": "access",
                    "refresh_token": "refresh",
                    "user": {
                        "id": "22222222-2222-2222-2222-222222222222",
                        "email": "new@example.com",
                        "email_confirmed_at": "2026-01-01T00:00:00Z",
                    },
                },
            )
        if "/auth/v1/token" in url:
            seen["token"] += 1
            return _FakeResponse(
                200,
                {
                    "user_id": "22222222-2222-2222-2222-222222222222",
                    "access_token": "access2",
                    "refresh_token": "refresh2",
                    "user": {"id": "22222222-2222-2222-2222-222222222222", "email": "new@example.com"},
                },
            )
        raise AssertionError(f"unexpected url {url}")

    fake = _FakeClient(handler)
    monkeypatch.setattr(httpx, "Client", lambda timeout=20.0: fake)
    client = TestClient(app)

    signup = client.post(
        "/api/auth/supabase/signup",
        json={"email": "new@example.com", "password": "ValidPass123!"},
    )
    assert signup.status_code == 200
    assert seen["signup"] == 1
    assert seen["token"] == 0

    login = client.post(
        "/api/auth/supabase/session",
        json={"email": "new@example.com", "password": "ValidPass123!"},
    )
    assert login.status_code == 200
    assert seen["token"] == 1


def test_existing_email_cannot_be_hijacked_via_signup(monkeypatch) -> None:
    _patch_settings(
        monkeypatch,
        hiair_auth_email_bridge_enabled=True,
        hiair_auth_provider="supabase",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.anon",
    )

    def handler(url, params=None, headers=None, json=None):  # noqa: A002
        assert "/admin/users" not in url
        # Supabase typically returns 422 / user already registered without confirming password change.
        return _FakeResponse(422, {"msg": "User already registered"})

    fake = _FakeClient(handler)
    monkeypatch.setattr(httpx, "Client", lambda timeout=20.0: fake)
    client = TestClient(app)
    response = client.post(
        "/api/auth/supabase/signup",
        json={"email": "taken@example.com", "password": "AttackerPass123!"},
    )
    assert response.status_code == 400
    # Safe generic message — no account existence leak / no password overwrite.
    assert "Unable to complete signup" in response.json()["detail"]
    assert "already" not in response.json()["detail"].lower()
    assert "registered" not in response.json()["detail"].lower()


def test_unconfirmed_email_not_auto_confirmed_via_bridge(monkeypatch) -> None:
    _patch_settings(
        monkeypatch,
        hiair_auth_email_bridge_enabled=True,
        hiair_auth_provider="supabase",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.anon",
    )

    def handler(url, params=None, headers=None, json=None):  # noqa: A002
        assert "email_confirm" not in (json or {})
        assert "/admin/users" not in url
        # Signup accepted, no session tokens → confirmation required.
        return _FakeResponse(
            200,
            {
                "user": {
                    "id": "33333333-3333-3333-3333-333333333333",
                    "email": "pending@example.com",
                    "email_confirmed_at": None,
                }
            },
        )

    fake = _FakeClient(handler)
    monkeypatch.setattr(httpx, "Client", lambda timeout=20.0: fake)
    client = TestClient(app)
    response = client.post(
        "/api/auth/supabase/signup",
        json={"email": "pending@example.com", "password": "ValidPass123!"},
    )
    assert response.status_code == 400
    assert "Unable to complete signup" in response.json()["detail"]
    body = response.json()
    assert "access_token" not in body
    assert "refresh_token" not in body
    assert "already" not in response.json()["detail"].lower()
    assert "exists" not in response.json()["detail"].lower()
    assert "confirm" not in response.json()["detail"].lower()


def test_signup_tokens_without_email_confirmation_require_confirmation(monkeypatch) -> None:
    """Regression: tokens + unconfirmed user must not become a usable session."""
    _patch_settings(
        monkeypatch,
        hiair_auth_email_bridge_enabled=True,
        hiair_auth_provider="supabase",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.anon",
    )

    def handler(url, params=None, headers=None, json=None):  # noqa: A002
        assert url.endswith("/auth/v1/signup")
        assert "email_confirm" not in (json or {})
        assert "/admin/users" not in url
        return _FakeResponse(
            200,
            {
                "access_token": "leaked-access-token",
                "refresh_token": "leaked-refresh-token",
                "user": {
                    "id": "55555555-5555-5555-5555-555555555555",
                    "email": "unconfirmed@example.com",
                    "email_confirmed_at": None,
                    "confirmed_at": None,
                },
            },
        )

    fake = _FakeClient(handler)
    monkeypatch.setattr(httpx, "Client", lambda timeout=20.0: fake)
    client = TestClient(app)
    response = client.post(
        "/api/auth/supabase/signup",
        json={"email": "unconfirmed@example.com", "password": "ValidPass123!"},
    )
    assert response.status_code == 400
    detail = response.json()["detail"].lower()
    assert "unable to complete signup" in detail
    # No account-enumeration / no session leak.
    body = response.json()
    assert "access_token" not in body
    assert "refresh_token" not in body
    assert "already" not in detail
    assert "exists" not in detail
    assert "leaked" not in detail
    assert "confirm" not in detail


def test_signup_confirmation_and_existing_email_share_uniform_response(monkeypatch) -> None:
    """Security: confirmation-required and existing-email must not enumerate."""
    _patch_settings(
        monkeypatch,
        hiair_auth_email_bridge_enabled=True,
        hiair_auth_provider="supabase",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.anon",
    )

    def confirmation_handler(url, params=None, headers=None, json=None):  # noqa: A002
        return _FakeResponse(
            200,
            {
                "access_token": "a",
                "refresh_token": "r",
                "user": {
                    "id": "66666666-6666-6666-6666-666666666666",
                    "email": "new@example.com",
                    "email_confirmed_at": None,
                },
            },
        )

    def existing_handler(url, params=None, headers=None, json=None):  # noqa: A002
        return _FakeResponse(422, {"msg": "User already registered"})

    client = TestClient(app)
    monkeypatch.setattr(httpx, "Client", lambda timeout=20.0: _FakeClient(confirmation_handler))
    confirmation = client.post(
        "/api/auth/supabase/signup",
        json={"email": "new@example.com", "password": "ValidPass123!"},
    )
    monkeypatch.setattr(httpx, "Client", lambda timeout=20.0: _FakeClient(existing_handler))
    existing = client.post(
        "/api/auth/supabase/signup",
        json={"email": "taken@example.com", "password": "ValidPass123!"},
    )
    assert confirmation.status_code == existing.status_code == 400
    assert confirmation.json()["detail"] == existing.json()["detail"]
    assert "access_token" not in confirmation.json()
    assert "access_token" not in existing.json()


def test_login_unconfirmed_does_not_reveal_confirmation_state(monkeypatch) -> None:
    _patch_settings(
        monkeypatch,
        hiair_auth_email_bridge_enabled=True,
        hiair_auth_provider="supabase",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.anon",
    )

    def handler(url, params=None, headers=None, json=None):  # noqa: A002
        return _FakeResponse(400, {"error_description": "Email not confirmed"})

    monkeypatch.setattr(httpx, "Client", lambda timeout=20.0: _FakeClient(handler))
    client = TestClient(app)
    response = client.post(
        "/api/auth/supabase/session",
        json={"email": "pending@example.com", "password": "ValidPass123!"},
    )
    assert response.status_code == 400
    detail = response.json()["detail"].lower()
    assert detail == "invalid email or password."
    assert "confirm" not in detail


def test_service_role_not_required_for_bridge(monkeypatch) -> None:
    _patch_settings(
        monkeypatch,
        hiair_auth_email_bridge_enabled=True,
        hiair_auth_provider="supabase",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.anon",
        supabase_service_role_key="",
    )

    def handler(url, params=None, headers=None, json=None):  # noqa: A002
        return _FakeResponse(
            200,
            {
                "user_id": "44444444-4444-4444-4444-444444444444",
                "access_token": "a",
                "refresh_token": "r",
                "user": {"id": "44444444-4444-4444-4444-444444444444", "email": "u@example.com"},
            },
        )

    fake = _FakeClient(handler)
    monkeypatch.setattr(httpx, "Client", lambda timeout=20.0: fake)
    client = TestClient(app)
    response = client.post(
        "/api/auth/supabase/session",
        json={"email": "u@example.com", "password": "ValidPass123!"},
    )
    assert response.status_code == 200


def test_bridge_disabled_returns_404(monkeypatch) -> None:
    _patch_settings(monkeypatch, hiair_auth_email_bridge_enabled=False)
    client = TestClient(app)
    response = client.post(
        "/api/auth/supabase/session",
        json={"email": "user@example.com", "password": "ValidPass123!"},
    )
    assert response.status_code == 404
