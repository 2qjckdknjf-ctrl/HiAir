from fastapi.testclient import TestClient

from app.api import deps
from app.core.settings import Settings
from app.main import app


def test_legacy_user_header_auth_disabled_by_default() -> None:
    client = TestClient(app)
    response = client.get("/api/settings", headers={"X-User-Id": "legacy-user-id"})
    assert response.status_code == 401
    assert response.json()["detail"] == "Missing authentication header"


def test_subscription_webhook_requires_secret_configuration() -> None:
    client = TestClient(app)
    response = client.post(
        "/api/subscriptions/webhook/stub",
        json={"id": "evt-test", "data": {"provider_subscription_id": "sub-test"}},
    )
    assert response.status_code in (401, 503)
    if response.status_code == 503:
        assert response.json()["detail"] == "Webhook secret is not configured"


def test_ops_admin_token_fails_closed_in_protected_env(monkeypatch) -> None:
    monkeypatch.setattr(
        deps,
        "settings",
        Settings(app_env="staging", notification_admin_token=""),
    )

    client = TestClient(app)
    response = client.get("/api/observability/metrics")

    assert response.status_code == 503
    assert response.json()["detail"] == "Notification admin token is not configured"
