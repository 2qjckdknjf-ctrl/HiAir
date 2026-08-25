from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import jwt
from fastapi.testclient import TestClient

import app.api.deps as deps
import app.services.supabase_auth as supabase_auth
from app.main import app
from app.models.subscription import SubscriptionStatusResponse


def _supabase_token(user_id: str, email: str = "demo@hiair.app") -> str:
    now = datetime.now(tz=UTC)
    payload = {
        "sub": user_id,
        "email": email,
        "role": "authenticated",
        "iss": "https://test-project.supabase.co/auth/v1",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=30)).timestamp()),
    }
    return jwt.encode(payload, "supabase-test-secret", algorithm="HS256")


def _configure_supabase(monkeypatch) -> None:
    cfg = SimpleNamespace(
        hiair_auth_provider="supabase",
        hiair_auth_legacy_enabled=False,
        supabase_url="https://test-project.supabase.co",
        supabase_jwt_secret="supabase-test-secret",
        notification_admin_token="",
        allow_insecure_local_dev=False,
        app_env="development",
    )
    monkeypatch.setattr(deps, "settings", cfg)
    monkeypatch.setattr(supabase_auth, "settings", cfg)
    supabase_auth._jwks_client.cache_clear()


def test_unauthenticated_request_is_rejected(monkeypatch) -> None:
    _configure_supabase(monkeypatch)
    client = TestClient(app)
    response = client.get("/api/auth/me")
    assert response.status_code == 401
    assert response.json()["detail"] == "Missing authentication header"


def test_valid_supabase_jwt_is_accepted_on_me(monkeypatch) -> None:
    _configure_supabase(monkeypatch)
    monkeypatch.setattr("app.api.auth.user_repository.list_profiles", lambda user_id: [])
    monkeypatch.setattr(
        "app.api.auth.subscription_repository.get_user_subscription",
        lambda user_id: SubscriptionStatusResponse(user_id=user_id, status="inactive"),
    )
    token = _supabase_token("00000000-0000-0000-0000-000000000111", "user111@hiair.app")
    client = TestClient(app)
    response = client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["user_id"] == "00000000-0000-0000-0000-000000000111"
    assert payload["email"] == "user111@hiair.app"
    assert payload["auth_provider"] == "supabase"


def test_invalid_supabase_jwt_is_rejected(monkeypatch) -> None:
    _configure_supabase(monkeypatch)
    client = TestClient(app)
    response = client.get("/api/auth/me", headers={"Authorization": "Bearer invalid.jwt.token"})
    assert response.status_code == 401
    assert "Invalid Supabase token" in response.json()["detail"]


def test_user_cannot_access_another_users_profile(monkeypatch) -> None:
    _configure_supabase(monkeypatch)
    monkeypatch.setattr("app.api.symptoms.profile_access.profile_exists", lambda _: True)
    monkeypatch.setattr("app.api.symptoms.profile_access.profile_belongs_to_user", lambda _profile_id, _user_id: False)
    token = _supabase_token("00000000-0000-0000-0000-000000000aaa")
    client = TestClient(app)
    response = client.get(
        "/api/symptoms/history",
        params={"profileId": "00000000-0000-0000-0000-000000000bbb"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 403, response.text
    assert response.json()["detail"] == "Profile does not belong to user"


def test_user_cannot_log_symptoms_for_another_users_profile(monkeypatch) -> None:
    _configure_supabase(monkeypatch)
    monkeypatch.setattr("app.api.symptoms.profile_access.profile_exists", lambda _: True)
    monkeypatch.setattr("app.api.symptoms.profile_access.profile_belongs_to_user", lambda _profile_id, _user_id: False)
    token = _supabase_token("00000000-0000-0000-0000-000000000aaa")
    client = TestClient(app)
    response = client.post(
        "/api/symptoms/log",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "profile_id": "00000000-0000-0000-0000-000000000bbb",
            "symptom": {
                "cough": False,
                "wheeze": False,
                "headache": False,
                "fatigue": False,
                "sleep_quality": 3,
            },
        },
    )
    assert response.status_code == 403, response.text
    assert response.json()["detail"] == "Profile does not belong to user"


def test_privacy_export_returns_only_own_data(monkeypatch) -> None:
    _configure_supabase(monkeypatch)
    monkeypatch.setattr(
        "app.api.privacy.privacy_repository.export_user_data",
        lambda user_id: {"user": {"id": user_id}, "profiles": [{"user_id": user_id}]},
    )
    token = _supabase_token("00000000-0000-0000-0000-000000000999")
    client = TestClient(app)
    response = client.get("/api/privacy/export", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["user_id"] == "00000000-0000-0000-0000-000000000999"
    assert payload["data"]["profiles"][0]["user_id"] == "00000000-0000-0000-0000-000000000999"


def test_delete_account_triggers_own_data_delete(monkeypatch) -> None:
    _configure_supabase(monkeypatch)
    calls: list[str] = []

    def _delete_account(**kwargs: object):
        user_id = str(kwargs.get("user_id", ""))
        calls.append(user_id)
        from app.services.account_deletion import AccountDeletionOutcome, DeletionStage, StageResult, StageStatus

        return AccountDeletionOutcome(
            completed=True,
            operation_id="op-test",
            stages=[
                StageResult(DeletionStage.APPLE_REVOKE, StageStatus.NOT_APPLICABLE),
                StageResult(DeletionStage.PUBLIC_DATA, StageStatus.COMPLETED),
                StageResult(DeletionStage.SUPABASE_AUTH, StageStatus.NOT_APPLICABLE),
            ],
        )

    monkeypatch.setattr("app.api.privacy.account_deletion_service.delete_account", _delete_account)
    token = _supabase_token("00000000-0000-0000-0000-000000000555")
    client = TestClient(app)
    response = client.post(
        "/api/privacy/delete-account",
        headers={"Authorization": f"Bearer {token}"},
        json={"confirmation": "DELETE"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["deleted"] is True
    assert calls == ["00000000-0000-0000-0000-000000000555"]
