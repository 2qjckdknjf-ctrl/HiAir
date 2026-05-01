from fastapi.testclient import TestClient

from app.main import app
from app.services import auth_guard
from app.services.user_repository import AuthError


def test_signup_rejects_weak_password(monkeypatch) -> None:
    auth_guard.reset_state_for_tests()
    called = {"create_user": False}

    def _create_user(email: str, password: str) -> str:
        called["create_user"] = True
        return "user-1"

    monkeypatch.setattr("app.api.auth.user_repository.create_user", _create_user)
    client = TestClient(app)
    response = client.post(
        "/api/auth/signup",
        json={"email": "weak@example.com", "password": "weakpass1"},
    )
    assert response.status_code == 422
    assert called["create_user"] is False


def test_login_locks_after_repeated_failed_attempts(monkeypatch) -> None:
    auth_guard.reset_state_for_tests()

    def _verify_user(email: str, password: str) -> str:
        raise AuthError("Invalid credentials")

    monkeypatch.setattr("app.api.auth.user_repository.verify_user", _verify_user)
    client = TestClient(app)
    payload = {"email": "user@example.com", "password": "WrongPass123!"}

    # First failures still return Invalid credentials.
    for _ in range(5):
        response = client.post("/api/auth/login", json=payload)
        assert response.status_code == 401

    # One extra failure triggers lock registration.
    locked_response = client.post("/api/auth/login", json=payload)
    assert locked_response.status_code == 401

    # Next attempt is blocked by account lock.
    locked_response = client.post("/api/auth/login", json=payload)
    assert locked_response.status_code == 429
    assert "temporarily locked" in locked_response.json()["detail"]


def test_refresh_rotates_token(monkeypatch) -> None:
    auth_guard.reset_state_for_tests()
    token_store = {
        "refresh-token-initial-0123456789abcd": {
            "user_id": "user-1",
            "revoked_at": None,
            "expires_at": "2099-01-01T00:00:00+00:00",
        }
    }

    def _get_active(refresh_token: str) -> dict | None:
        return token_store.get(refresh_token)

    def _revoke(refresh_token: str) -> bool:
        token_store.pop(refresh_token, None)
        return True

    def _create(user_id: str, refresh_token: str, expires_at) -> None:
        token_store[refresh_token] = {
            "user_id": user_id,
            "revoked_at": None,
            "expires_at": expires_at,
        }

    monkeypatch.setattr("app.api.auth.auth_tokens_repository.get_active_refresh_token", _get_active)
    monkeypatch.setattr("app.api.auth.auth_tokens_repository.revoke_refresh_token", _revoke)
    monkeypatch.setattr("app.api.auth.auth_tokens_repository.create_refresh_token", _create)
    client = TestClient(app)
    response = client.post(
        "/api/auth/refresh",
        json={"refresh_token": "refresh-token-initial-0123456789abcd"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["user_id"] == "user-1"
    assert isinstance(body["access_token"], str) and body["access_token"]
    assert isinstance(body["refresh_token"], str) and body["refresh_token"]
    assert body["refresh_token"] != "refresh-token-initial-0123456789abcd"
