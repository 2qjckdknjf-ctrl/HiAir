from dataclasses import replace

from fastapi.testclient import TestClient

from app.core import settings as settings_module
from app.main import app


def _patch_settings(monkeypatch, **kwargs):
    cfg = replace(settings_module.settings, **kwargs)
    monkeypatch.setattr(settings_module, "settings", cfg)
    monkeypatch.setattr("app.api.auth_supabase_bridge.settings", cfg)


def test_supabase_bridge_disabled_returns_404(monkeypatch) -> None:
    _patch_settings(monkeypatch, hiair_auth_email_bridge_enabled=False)
    client = TestClient(app)
    response = client.post(
        "/api/auth/supabase/session",
        json={"email": "user@example.com", "password": "ValidPass123!"},
    )
    assert response.status_code == 404


def test_supabase_bridge_returns_session(monkeypatch) -> None:
    _patch_settings(
        monkeypatch,
        hiair_auth_email_bridge_enabled=True,
        hiair_auth_provider="supabase",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test",
    )

    def _issue(email: str, password: str) -> dict[str, str]:
        assert email == "user@example.com"
        assert password == "ValidPass123!"
        return {
            "user_id": "11111111-1111-1111-1111-111111111111",
            "email": email,
            "access_token": "access-token",
            "refresh_token": "refresh-token",
        }

    monkeypatch.setattr(
        "app.api.auth_supabase_bridge.password_grant_session",
        _issue,
    )
    client = TestClient(app)
    response = client.post(
        "/api/auth/supabase/session",
        json={"email": "user@example.com", "password": "ValidPass123!"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["user_id"] == "11111111-1111-1111-1111-111111111111"
    assert payload["access_token"] == "access-token"
    assert payload["refresh_token"] == "refresh-token"


def test_supabase_bridge_signup_uses_signup_helper(monkeypatch) -> None:
    _patch_settings(
        monkeypatch,
        hiair_auth_email_bridge_enabled=True,
        hiair_auth_provider="supabase",
        supabase_url="https://example.supabase.co",
        supabase_anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test",
    )

    def _signup(email: str, password: str) -> dict[str, str]:
        assert email == "user@example.com"
        return {
            "user_id": "11111111-1111-1111-1111-111111111111",
            "email": email,
            "access_token": "access-token",
            "refresh_token": "refresh-token",
        }

    monkeypatch.setattr(
        "app.api.auth_supabase_bridge.signup_with_password",
        _signup,
    )
    client = TestClient(app)
    response = client.post(
        "/api/auth/supabase/signup",
        json={"email": "user@example.com", "password": "ValidPass123!"},
    )
    assert response.status_code == 200
