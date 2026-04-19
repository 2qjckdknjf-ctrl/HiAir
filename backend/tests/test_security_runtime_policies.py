from fastapi.testclient import TestClient

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
