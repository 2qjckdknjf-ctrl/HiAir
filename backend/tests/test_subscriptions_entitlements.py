from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

from fastapi.testclient import TestClient

import app.api.subscriptions as subscriptions_api
import app.api.deps as deps
import app.api.profiles as profiles_api
import app.api.recommendations as recommendations_api
from app.main import app
from app.models.subscription import UserEntitlementResponse
import app.services.entitlement_service as entitlement_service
from app.services.subscription_store import (
    ANDROID_MONTHLY,
    IOS_MONTHLY,
    build_stub_ios_jws,
    verify_android_purchase,
    verify_ios_purchase,
)


def _auth_headers() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def _premium_entitlement(user_id: str = "user-1") -> UserEntitlementResponse:
    return UserEntitlementResponse(
        user_id=user_id,
        plan="premium",
        is_premium=True,
        premium_until=datetime.now(tz=UTC) + timedelta(days=30),
        max_profiles=6,
        extended_forecast_enabled=True,
        custom_alerts_enabled=True,
        export_reports_enabled=True,
        advanced_insights_enabled=True,
    )


def _free_entitlement(user_id: str = "user-1") -> UserEntitlementResponse:
    return UserEntitlementResponse(user_id=user_id)


def test_free_entitlement_defaults() -> None:
    ent = entitlement_service._free_entitlement("user-free")
    assert ent.plan == "free"
    assert ent.is_premium is False
    assert ent.max_profiles == 1
    assert ent.extended_forecast_enabled is False


def test_expired_ios_does_not_grant_premium_status() -> None:
    expired = datetime.now(tz=UTC) - timedelta(days=1)
    purchase = verify_ios_purchase(build_stub_ios_jws(IOS_MONTHLY, expires_at=expired), product_id=IOS_MONTHLY)
    assert purchase.status == "expired"
    assert purchase.status not in ("active", "trialing", "grace_period")


def test_android_canceled_does_not_grant_premium_status() -> None:
    purchase = verify_android_purchase(ANDROID_MONTHLY, "token:canceled")
    assert purchase.status == "canceled"
    assert purchase.status not in ("active", "trialing", "grace_period")


def test_invalid_webhook_signature_rejected(monkeypatch) -> None:
    import app.services.subscription_provider as subscription_provider

    monkeypatch.setattr(
        subscriptions_api,
        "settings",
        SimpleNamespace(subscription_provider="stub", subscription_webhook_secret="test-secret"),
    )
    monkeypatch.setattr(subscription_provider, "verify_webhook_signature", lambda **kwargs: False)
    client = TestClient(app)
    response = client.post(
        "/api/subscriptions/webhook/stub",
        content=b"{}",
        headers={"X-Webhook-Signature": "bad", "Content-Type": "application/json"},
    )
    assert response.status_code == 401


def test_plans_include_store_product_ids() -> None:
    client = TestClient(app)
    response = client.get("/api/subscriptions/plans")
    assert response.status_code == 200
    plans = {p["plan_id"]: p for p in response.json()}
    assert plans["premium_monthly"]["ios_product_id"] == IOS_MONTHLY
    assert plans["premium_monthly"]["android_product_id"] == ANDROID_MONTHLY


def test_ios_verify_grants_premium(monkeypatch) -> None:
    monkeypatch.setattr(deps, "decode_access_token", lambda token: "user-1")
    monkeypatch.setattr(deps.user_repository, "user_exists", lambda user_id: True)
    called: list[str] = []

    def _apply(user_id: str, purchase):  # noqa: ANN001
        called.append(user_id)
        return SimpleNamespace(
            user_id=user_id,
            plan_id="premium_monthly",
            status="active",
            entitlement=_premium_entitlement(user_id),
        )

    monkeypatch.setattr(subscriptions_api.subscription_repository, "apply_verified_purchase", _apply)
    jws = build_stub_ios_jws(IOS_MONTHLY)
    client = TestClient(app)
    response = client.post(
        "/api/subscriptions/ios/verify",
        json={"signed_transaction": jws, "product_id": IOS_MONTHLY},
        headers=_auth_headers(),
    )
    assert response.status_code == 200
    assert called == ["user-1"]


def test_expired_ios_stub_token_yields_expired_status() -> None:
    expired = datetime.now(tz=UTC) - timedelta(days=2)
    jws = build_stub_ios_jws(IOS_MONTHLY, expires_at=expired, status="active")
    purchase = verify_ios_purchase(jws, product_id=IOS_MONTHLY)
    assert purchase.status == "expired"


def test_android_verify_grants_premium(monkeypatch) -> None:
    monkeypatch.setattr(deps, "decode_access_token", lambda token: "user-2")
    monkeypatch.setattr(deps.user_repository, "user_exists", lambda user_id: True)
    monkeypatch.setattr(
        subscriptions_api.subscription_repository,
        "apply_verified_purchase",
        lambda user_id, purchase: SimpleNamespace(
            user_id=user_id,
            status="active",
            entitlement=_premium_entitlement(user_id),
        ),
    )
    client = TestClient(app)
    response = client.post(
        "/api/subscriptions/android/verify",
        json={"product_id": ANDROID_MONTHLY, "purchase_token": "test-token-abc"},
        headers=_auth_headers(),
    )
    assert response.status_code == 200


def test_android_expired_token_suffix() -> None:
    purchase = verify_android_purchase(ANDROID_MONTHLY, "tok:expired")
    assert purchase.status == "expired"


def test_stub_activate_blocked_in_production(monkeypatch) -> None:
    monkeypatch.setattr(deps, "decode_access_token", lambda token: "user-1")
    monkeypatch.setattr(deps.user_repository, "user_exists", lambda user_id: True)
    monkeypatch.setattr(
        subscriptions_api,
        "settings",
        SimpleNamespace(app_env="production", subscription_provider="stub"),
    )
    client = TestClient(app)
    response = client.post(
        "/api/subscriptions/activate",
        json={"plan_id": "premium_monthly", "use_trial": False},
        headers=_auth_headers(),
    )
    assert response.status_code == 403


def test_stub_activate_blocked_when_provider_not_stub(monkeypatch) -> None:
    monkeypatch.setattr(deps, "decode_access_token", lambda token: "user-1")
    monkeypatch.setattr(deps.user_repository, "user_exists", lambda user_id: True)
    monkeypatch.setattr(
        subscriptions_api,
        "settings",
        SimpleNamespace(app_env="development", subscription_provider="apple"),
    )
    client = TestClient(app)
    response = client.post(
        "/api/subscriptions/activate",
        json={"plan_id": "premium_monthly", "use_trial": False},
        headers=_auth_headers(),
    )
    assert response.status_code == 403
    assert "SUBSCRIPTION_PROVIDER=stub" in response.json()["detail"]


def test_free_user_blocked_from_premium_recommendations(monkeypatch) -> None:
    monkeypatch.setattr(deps, "decode_access_token", lambda token: "user-1")
    monkeypatch.setattr(deps.user_repository, "user_exists", lambda user_id: True)
    monkeypatch.setattr(
        recommendations_api.entitlement_service,
        "require_feature",
        lambda user_id, feature, attr: (_ for _ in ()).throw(
            __import__("fastapi").HTTPException(status_code=402, detail="premium required")
        ),
    )
    monkeypatch.setattr(
        recommendations_api.profile_access,
        "profile_exists",
        lambda profile_id: True,
    )
    monkeypatch.setattr(
        recommendations_api.profile_access,
        "profile_belongs_to_user",
        lambda profile_id, user_id: True,
    )
    client = TestClient(app)
    response = client.get(
        "/api/recommendations/daily",
        params={"profile_id": "profile-1"},
        headers=_auth_headers(),
    )
    assert response.status_code == 402


def test_profile_limit_enforced(monkeypatch) -> None:
    monkeypatch.setattr(deps, "decode_access_token", lambda token: "user-1")
    monkeypatch.setattr(deps.user_repository, "user_exists", lambda user_id: True)
    monkeypatch.setattr(
        profiles_api.entitlement_service,
        "assert_profile_limit",
        lambda user_id: (_ for _ in ()).throw(
            __import__("fastapi").HTTPException(status_code=402, detail="Profile limit reached")
        ),
    )
    client = TestClient(app)
    response = client.post(
        "/api/profiles",
        json={
            "persona_type": "adult",
            "sensitivity_level": "medium",
            "home_lat": 41.0,
            "home_lon": 2.0,
        },
        headers=_auth_headers(),
    )
    assert response.status_code == 402


def test_webhook_idempotency_duplicate_flag(monkeypatch) -> None:
    import app.services.subscription_provider as subscription_provider

    monkeypatch.setattr(
        subscriptions_api,
        "settings",
        SimpleNamespace(subscription_provider="stub", subscription_webhook_secret="test-secret"),
    )
    monkeypatch.setattr(subscription_provider, "verify_webhook_signature", lambda **kwargs: True)
    event = SimpleNamespace(
        event_id="evt-dup",
        event_type="subscription.updated",
        provider_subscription_id="sub-dup",
        user_id="user-1",
        plan_id="premium_monthly",
        status="active",
        current_period_end=datetime.now(tz=UTC) + timedelta(days=10),
        auto_renew=True,
        platform=None,
        product_id=None,
        original_transaction_id=None,
        purchase_token=None,
    )
    monkeypatch.setattr(subscription_provider, "parse_webhook_event", lambda provider, payload: event)
    monkeypatch.setattr(subscriptions_api.subscription_repository, "record_webhook_event", lambda provider, event: False)
    monkeypatch.setattr(
        subscriptions_api.subscription_repository,
        "apply_provider_webhook_event",
        lambda event: (_ for _ in ()).throw(AssertionError("should not apply duplicate")),
    )

    import hashlib
    import hmac

    body = b'{"id":"evt-dup","data":{"provider_subscription_id":"sub-dup","user_id":"user-1"}}'
    signature = hmac.new(b"test-secret", body, hashlib.sha256).hexdigest()
    client = TestClient(app)
    response = client.post(
        "/api/subscriptions/webhook/stub",
        content=body,
        headers={"X-Webhook-Signature": signature, "Content-Type": "application/json"},
    )
    assert response.status_code == 200
    assert response.json()["duplicate"] is True
