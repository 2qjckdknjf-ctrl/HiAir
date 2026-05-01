from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

import app.api.deps as deps
import app.api.subscriptions as subscriptions_api
from app.main import app
from app.models.subscription import ProviderWebhookEvent


def test_require_ops_admin_token_rejects_missing_token_in_protected_env(monkeypatch) -> None:
    monkeypatch.setattr(
        deps,
        "settings",
        SimpleNamespace(
            notification_admin_token="",
            allow_insecure_local_dev=False,
            app_env="staging",
        ),
    )
    with pytest.raises(HTTPException) as exc_info:
        deps.require_ops_admin_token(None)
    assert exc_info.value.status_code == 503
    assert exc_info.value.detail == "Notification admin token is not configured"


def test_require_ops_admin_token_allows_explicit_local_dev_bypass(monkeypatch) -> None:
    monkeypatch.setattr(
        deps,
        "settings",
        SimpleNamespace(
            notification_admin_token="",
            allow_insecure_local_dev=True,
            app_env="development",
        ),
    )
    assert deps.require_ops_admin_token(None) is True


def test_subscription_webhook_rejects_invalid_signature(monkeypatch) -> None:
    monkeypatch.setattr(
        subscriptions_api,
        "settings",
        SimpleNamespace(subscription_provider="stub", subscription_webhook_secret="test-secret"),
    )
    monkeypatch.setattr(
        subscriptions_api.subscription_provider,
        "verify_webhook_signature",
        lambda raw_body, signature, secret: False,
    )

    client = TestClient(app)
    response = client.post(
        "/api/subscriptions/webhook/stub",
        json={"id": "evt-1", "data": {"provider_subscription_id": "sub-1"}},
        headers={"X-Webhook-Signature": "sha256=bad"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid webhook signature"


def test_subscription_webhook_accepts_valid_signature(monkeypatch) -> None:
    monkeypatch.setattr(
        subscriptions_api,
        "settings",
        SimpleNamespace(subscription_provider="stub", subscription_webhook_secret="test-secret"),
    )
    monkeypatch.setattr(
        subscriptions_api.subscription_provider,
        "verify_webhook_signature",
        lambda raw_body, signature, secret: True,
    )
    monkeypatch.setattr(
        subscriptions_api.subscription_provider,
        "parse_webhook_event",
        lambda provider, payload: ProviderWebhookEvent(
            event_id="evt-2",
            event_type="subscription.updated",
            provider_subscription_id="sub-2",
            user_id="user-2",
            plan_id="basic_monthly",
            status="active",
            current_period_end=None,
            auto_renew=True,
        ),
    )
    monkeypatch.setattr(
        subscriptions_api.subscription_repository,
        "record_webhook_event",
        lambda provider, event: True,
    )
    monkeypatch.setattr(
        subscriptions_api.subscription_repository,
        "apply_provider_webhook_event",
        lambda event: None,
    )

    client = TestClient(app)
    response = client.post(
        "/api/subscriptions/webhook/stub",
        json={"id": "evt-2", "data": {"provider_subscription_id": "sub-2"}},
        headers={"X-Webhook-Signature": "sha256=good"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["accepted"] is True
    assert body["event_id"] == "evt-2"
    assert body["duplicate"] is False
