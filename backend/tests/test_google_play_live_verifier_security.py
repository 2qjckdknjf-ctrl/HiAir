"""Security regression tests for live Google Play subscription verification."""

from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace

import pytest

from app.services import subscription_store as store
from app.services.subscription_store import (
    ANDROID_MONTHLY,
    ANDROID_YEARLY,
    verified_purchase_from_google_subscription,
    verify_android_purchase,
)


def _expiry(days: int = 30) -> str:
    return (datetime.now(tz=UTC) + timedelta(days=days)).strftime("%Y-%m-%dT%H:%M:%SZ")


def _active_payload(**overrides) -> dict:
    payload = {
        "packageName": "com.hiair",
        "subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
        "latestOrderId": "GPA.1234-5678",
        "lineItems": [
            {
                "productId": ANDROID_MONTHLY,
                "expiryTime": _expiry(30),
                "autoRenewingPlan": {"autoRenewEnabled": True},
            }
        ],
    }
    payload.update(overrides)
    return payload


def _live_env(monkeypatch) -> None:
    monkeypatch.setenv("GOOGLE_PLAY_VERIFIER_MODE", "live")
    monkeypatch.setenv("GOOGLE_PLAY_PACKAGE_NAME", "com.hiair")
    monkeypatch.setenv(
        "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
        json.dumps(
            {
                "client_email": "svc@test.iam.gserviceaccount.com",
                "private_key": "-----BEGIN PRIVATE KEY-----\nTEST\n-----END PRIVATE KEY-----\n",
            }
        ),
    )


def _premium_statuses() -> set[str]:
    return {"active", "trialing", "grace_period"}


def test_live_accepts_verified_active_fixture() -> None:
    purchase = verified_purchase_from_google_subscription(
        _active_payload(),
        package_name="com.hiair",
        product_id=ANDROID_MONTHLY,
        purchase_token="tok-live-1",
    )
    assert purchase.status == "active"
    assert purchase.product_id == ANDROID_MONTHLY
    assert purchase.transaction_id == "GPA.1234-5678"
    assert purchase.auto_renew is True


def test_live_selects_exact_product_among_multiple_line_items() -> None:
    payload = _active_payload(
        lineItems=[
            {
                "productId": ANDROID_YEARLY,
                "expiryTime": _expiry(10),
                "autoRenewingPlan": {"autoRenewEnabled": False},
            },
            {
                "productId": ANDROID_MONTHLY,
                "expiryTime": _expiry(30),
                "autoRenewingPlan": {"autoRenewEnabled": True},
            },
            {
                "productId": "hiair_premium_other",
                "expiryTime": _expiry(5),
                "autoRenewingPlan": {"autoRenewEnabled": True},
            },
        ]
    )
    purchase = verified_purchase_from_google_subscription(
        payload,
        package_name="com.hiair",
        product_id=ANDROID_MONTHLY,
        purchase_token="tok-live-1",
    )
    assert purchase.product_id == ANDROID_MONTHLY
    assert purchase.auto_renew is True
    assert purchase.status == "active"


def test_live_rejects_ambiguous_duplicate_exact_product_line_items() -> None:
    """Two lineItems with the same productId must fail closed (no first-wins)."""
    payload = _active_payload(
        lineItems=[
            {
                "productId": ANDROID_MONTHLY,
                "expiryTime": _expiry(10),
                "autoRenewingPlan": {"autoRenewEnabled": True},
            },
            {
                "productId": ANDROID_MONTHLY,
                "expiryTime": _expiry(30),
                "autoRenewingPlan": {"autoRenewEnabled": False},
            },
        ]
    )
    with pytest.raises(ValueError, match="ambiguous duplicate lineItems"):
        verified_purchase_from_google_subscription(
            payload,
            package_name="com.hiair",
            product_id=ANDROID_MONTHLY,
            purchase_token="tok-live-1",
        )


def test_live_prepaid_plan_auto_renew_is_false() -> None:
    payload = _active_payload(
        lineItems=[
            {
                "productId": ANDROID_MONTHLY,
                "expiryTime": _expiry(30),
                "prepaidPlan": {"allowExtendAfterTime": _expiry(5)},
            }
        ]
    )
    purchase = verified_purchase_from_google_subscription(
        payload,
        package_name="com.hiair",
        product_id=ANDROID_MONTHLY,
        purchase_token="tok-live-1",
    )
    assert purchase.auto_renew is False
    assert purchase.status == "active"


@pytest.mark.parametrize(
    "auto_renewing_plan",
    [
        {},  # missing autoRenewEnabled
        {"autoRenewEnabled": None},
        {"autoRenewEnabled": "true"},
        {"autoRenewEnabled": 1},
    ],
)
def test_live_rejects_missing_or_invalid_auto_renew_enabled(auto_renewing_plan: dict) -> None:
    payload = _active_payload(
        lineItems=[
            {
                "productId": ANDROID_MONTHLY,
                "expiryTime": _expiry(30),
                "autoRenewingPlan": auto_renewing_plan,
            }
        ]
    )
    with pytest.raises(ValueError, match="autoRenew"):
        verified_purchase_from_google_subscription(
            payload,
            package_name="com.hiair",
            product_id=ANDROID_MONTHLY,
            purchase_token="tok-live-1",
        )


def test_live_rejects_line_item_without_plan_type() -> None:
    payload = _active_payload(
        lineItems=[
            {
                "productId": ANDROID_MONTHLY,
                "expiryTime": _expiry(30),
            }
        ]
    )
    with pytest.raises(ValueError, match="autoRenewingPlan or prepaidPlan"):
        verified_purchase_from_google_subscription(
            payload,
            package_name="com.hiair",
            product_id=ANDROID_MONTHLY,
            purchase_token="tok-live-1",
        )


def test_live_rejects_line_item_with_both_plan_types() -> None:
    payload = _active_payload(
        lineItems=[
            {
                "productId": ANDROID_MONTHLY,
                "expiryTime": _expiry(30),
                "autoRenewingPlan": {"autoRenewEnabled": True},
                "prepaidPlan": {"allowExtendAfterTime": _expiry(5)},
            }
        ]
    )
    with pytest.raises(ValueError, match="both prepaidPlan and autoRenewingPlan"):
        verified_purchase_from_google_subscription(
            payload,
            package_name="com.hiair",
            product_id=ANDROID_MONTHLY,
            purchase_token="tok-live-1",
        )


def test_live_rejects_wrong_product_id_no_first_item_fallback() -> None:
    payload = _active_payload(
        lineItems=[
            {
                "productId": ANDROID_YEARLY,
                "expiryTime": _expiry(30),
                "autoRenewingPlan": {"autoRenewEnabled": True},
            }
        ]
    )
    with pytest.raises(ValueError, match="product ID mismatch"):
        verified_purchase_from_google_subscription(
            payload,
            package_name="com.hiair",
            product_id=ANDROID_MONTHLY,
            purchase_token="tok-live-1",
        )


@pytest.mark.parametrize(
    "expiry_value",
    [None, "", "   "],
)
def test_live_rejects_missing_or_empty_expiry_no_plan_synthesis(expiry_value: object) -> None:
    item: dict = {
        "productId": ANDROID_MONTHLY,
        "autoRenewingPlan": {"autoRenewEnabled": True},
    }
    if expiry_value is not None:
        item["expiryTime"] = expiry_value
    payload = _active_payload(lineItems=[item])
    with pytest.raises(ValueError, match="expiryTime"):
        verified_purchase_from_google_subscription(
            payload,
            package_name="com.hiair",
            product_id=ANDROID_MONTHLY,
            purchase_token="tok-live-1",
        )


def test_live_rejects_invalid_expiry_timestamp() -> None:
    payload = _active_payload(
        lineItems=[
            {
                "productId": ANDROID_MONTHLY,
                "expiryTime": "not-a-valid-timestamp",
                "autoRenewingPlan": {"autoRenewEnabled": True},
            }
        ]
    )
    with pytest.raises(ValueError):
        verified_purchase_from_google_subscription(
            payload,
            package_name="com.hiair",
            product_id=ANDROID_MONTHLY,
            purchase_token="tok-live-1",
        )


@pytest.mark.parametrize("order_id", [None, "", "   "])
def test_live_rejects_missing_or_empty_latest_order_id_no_token_hash(order_id: object) -> None:
    payload = _active_payload()
    if order_id is None:
        del payload["latestOrderId"]
    else:
        payload["latestOrderId"] = order_id
    with pytest.raises(ValueError, match="latestOrderId"):
        verified_purchase_from_google_subscription(
            payload,
            package_name="com.hiair",
            product_id=ANDROID_MONTHLY,
            purchase_token="tok-live-1",
        )


@pytest.mark.parametrize(
    "missing_key",
    ["subscriptionState", "lineItems"],
)
def test_live_rejects_missing_required_top_level_fields(missing_key: str) -> None:
    payload = _active_payload()
    del payload[missing_key]
    with pytest.raises(ValueError):
        verified_purchase_from_google_subscription(
            payload,
            package_name="com.hiair",
            product_id=ANDROID_MONTHLY,
            purchase_token="tok-live-1",
        )


def test_live_rejects_empty_line_items_list() -> None:
    payload = _active_payload(lineItems=[])
    with pytest.raises(ValueError, match="lineItems"):
        verified_purchase_from_google_subscription(
            payload,
            package_name="com.hiair",
            product_id=ANDROID_MONTHLY,
            purchase_token="tok-live-1",
        )


def test_live_rejects_unspecified_and_unknown_states() -> None:
    for state in ("SUBSCRIPTION_STATE_UNSPECIFIED", "SUBSCRIPTION_STATE_MADE_UP", "", "   "):
        payload = _active_payload(subscriptionState=state)
        with pytest.raises(ValueError):
            verified_purchase_from_google_subscription(
                payload,
                package_name="com.hiair",
                product_id=ANDROID_MONTHLY,
                purchase_token="tok-live-1",
            )


def test_live_rejects_package_name_mismatch() -> None:
    payload = _active_payload(packageName="com.other.app")
    with pytest.raises(ValueError, match="package name mismatch"):
        verified_purchase_from_google_subscription(
            payload,
            package_name="com.hiair",
            product_id=ANDROID_MONTHLY,
            purchase_token="tok-live-1",
        )


def test_live_expired_does_not_grant_active_premium() -> None:
    past = (datetime.now(tz=UTC) - timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
    payload = _active_payload(
        lineItems=[
            {
                "productId": ANDROID_MONTHLY,
                "expiryTime": past,
                "autoRenewingPlan": {"autoRenewEnabled": True},
            }
        ]
    )
    purchase = verified_purchase_from_google_subscription(
        payload,
        package_name="com.hiair",
        product_id=ANDROID_MONTHLY,
        purchase_token="tok-live-1",
    )
    assert purchase.status == "expired"
    assert purchase.status not in _premium_statuses()


def test_live_canceled_within_period_is_active_without_renew() -> None:
    payload = _active_payload(subscriptionState="SUBSCRIPTION_STATE_CANCELED")
    purchase = verified_purchase_from_google_subscription(
        payload,
        package_name="com.hiair",
        product_id=ANDROID_MONTHLY,
        purchase_token="tok-live-1",
    )
    assert purchase.status == "active"
    assert purchase.auto_renew is False
    assert purchase.status in _premium_statuses()


@pytest.mark.parametrize(
    ("state", "expected_status", "grants_premium"),
    [
        ("SUBSCRIPTION_STATE_IN_GRACE_PERIOD", "grace_period", True),
        ("SUBSCRIPTION_STATE_PENDING", "inactive", False),
        ("SUBSCRIPTION_STATE_PAUSED", "inactive", False),
        ("SUBSCRIPTION_STATE_ON_HOLD", "inactive", False),
        ("SUBSCRIPTION_STATE_EXPIRED", "expired", False),
    ],
)
def test_live_state_semantics_match_entitlement_contract(
    state: str,
    expected_status: str,
    grants_premium: bool,
) -> None:
    purchase = verified_purchase_from_google_subscription(
        _active_payload(subscriptionState=state),
        package_name="com.hiair",
        product_id=ANDROID_MONTHLY,
        purchase_token="tok-live-1",
    )
    assert purchase.status == expected_status
    assert (purchase.status in _premium_statuses()) is grants_premium


def test_live_rejects_empty_purchase_token() -> None:
    with pytest.raises(ValueError, match="purchase token"):
        verified_purchase_from_google_subscription(
            _active_payload(),
            package_name="com.hiair",
            product_id=ANDROID_MONTHLY,
            purchase_token="   ",
        )


def test_live_rejects_unknown_product_before_network(monkeypatch) -> None:
    _live_env(monkeypatch)
    called = {"n": 0}

    def _boom(*_args, **_kwargs):  # noqa: ANN001
        called["n"] += 1
        raise AssertionError("network must not be called for unknown product")

    monkeypatch.setattr(store, "_load_google_service_account", _boom)
    with pytest.raises(ValueError, match="Unknown store product_id"):
        verify_android_purchase("com.hiair.not.a.product", "tok")
    assert called["n"] == 0


def test_live_verifier_unavailable_does_not_grant_premium(monkeypatch) -> None:
    _live_env(monkeypatch)
    monkeypatch.setattr(
        store,
        "_load_google_service_account",
        lambda: {
            "client_email": "svc@test.iam.gserviceaccount.com",
            "private_key": "-----BEGIN PRIVATE KEY-----\nTEST\n-----END PRIVATE KEY-----\n",
        },
    )
    monkeypatch.setattr(store, "_google_access_token", lambda _sa: (_ for _ in ()).throw(RuntimeError("oauth down")))
    with pytest.raises(RuntimeError, match="verifier unavailable"):
        verify_android_purchase(ANDROID_MONTHLY, "tok-live-1")


def test_live_never_falls_back_to_stub_on_fetch_failure(monkeypatch) -> None:
    _live_env(monkeypatch)
    monkeypatch.setattr(
        store,
        "_load_google_service_account",
        lambda: {
            "client_email": "svc@test.iam.gserviceaccount.com",
            "private_key": "-----BEGIN PRIVATE KEY-----\nTEST\n-----END PRIVATE KEY-----\n",
        },
    )
    monkeypatch.setattr(store, "_google_access_token", lambda _sa: "access-token")

    def _fail(*_args, **_kwargs):  # noqa: ANN001
        raise ConnectionError("network down")

    monkeypatch.setattr(store, "_google_fetch_subscription_v2", _fail)
    with pytest.raises(RuntimeError, match="verifier unavailable"):
        verify_android_purchase(ANDROID_MONTHLY, "tok-live-1")


def test_service_account_requires_client_email_and_private_key(monkeypatch) -> None:
    monkeypatch.setenv("GOOGLE_PLAY_VERIFIER_MODE", "live")
    monkeypatch.setenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", json.dumps({"type": "service_account"}))
    with pytest.raises(RuntimeError, match="client_email"):
        store._load_google_service_account()


def test_service_account_requires_private_key(monkeypatch) -> None:
    monkeypatch.setenv(
        "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
        json.dumps({"client_email": "svc@test.iam.gserviceaccount.com"}),
    )
    with pytest.raises(RuntimeError, match="private_key"):
        store._load_google_service_account()


def test_service_account_rejects_malformed_json(monkeypatch) -> None:
    monkeypatch.setenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "{not-json")
    with pytest.raises(json.JSONDecodeError):
        store._load_google_service_account()


def test_service_account_loads_from_file(tmp_path: Path, monkeypatch) -> None:
    path = tmp_path / "sa.json"
    path.write_text(
        json.dumps(
            {
                "client_email": "svc@test.iam.gserviceaccount.com",
                "private_key": "-----BEGIN PRIVATE KEY-----\nTEST\n-----END PRIVATE KEY-----\n",
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", str(path))
    data = store._load_google_service_account()
    assert data["client_email"] == "svc@test.iam.gserviceaccount.com"


def test_service_account_rejects_non_object_json(monkeypatch) -> None:
    monkeypatch.setenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", json.dumps(["not", "an", "object"]))
    with pytest.raises(RuntimeError, match="JSON object"):
        store._load_google_service_account()


def test_fetch_404_is_value_error_not_stub(monkeypatch) -> None:
    response = SimpleNamespace(status_code=404, raise_for_status=lambda: None, json=lambda: {})

    class _FakeHttpx:
        @staticmethod
        def get(*_args, **_kwargs):  # noqa: ANN001
            return response

    monkeypatch.setattr(store, "httpx", _FakeHttpx)
    with pytest.raises(ValueError, match="not found"):
        store._google_fetch_subscription_v2("com.hiair", "tok", "access")


def test_fetch_invalid_response_body_rejected(monkeypatch) -> None:
    response = SimpleNamespace(
        status_code=200,
        raise_for_status=lambda: None,
        json=lambda: ["not", "a", "dict"],
    )

    class _FakeHttpx:
        @staticmethod
        def get(*_args, **_kwargs):  # noqa: ANN001
            return response

    monkeypatch.setattr(store, "httpx", _FakeHttpx)
    with pytest.raises(ValueError, match="Invalid Google Play subscription response"):
        store._google_fetch_subscription_v2("com.hiair", "tok", "access")


def test_oauth_missing_access_token_fails_closed(monkeypatch) -> None:
    response = SimpleNamespace(
        raise_for_status=lambda: None,
        json=lambda: {"token_type": "Bearer"},
    )

    class _FakeHttpx:
        @staticmethod
        def post(*_args, **_kwargs):  # noqa: ANN001
            return response

    monkeypatch.setattr(store, "httpx", _FakeHttpx)
    monkeypatch.setattr(store.jwt, "encode", lambda *_a, **_k: "assertion")
    with pytest.raises(RuntimeError, match="OAuth token exchange failed"):
        store._google_access_token(
            {
                "client_email": "svc@test.iam.gserviceaccount.com",
                "private_key": "-----BEGIN PRIVATE KEY-----\nTEST\n-----END PRIVATE KEY-----\n",
            }
        )


def test_live_http_error_becomes_verifier_unavailable(monkeypatch) -> None:
    _live_env(monkeypatch)
    monkeypatch.setattr(
        store,
        "_load_google_service_account",
        lambda: {
            "client_email": "svc@test.iam.gserviceaccount.com",
            "private_key": "-----BEGIN PRIVATE KEY-----\nTEST\n-----END PRIVATE KEY-----\n",
        },
    )
    monkeypatch.setattr(store, "_google_access_token", lambda _sa: "access-token")

    class _HTTPError(Exception):
        pass

    def _fail(*_args, **_kwargs):  # noqa: ANN001
        raise _HTTPError("500")

    monkeypatch.setattr(store, "_google_fetch_subscription_v2", _fail)
    with pytest.raises(RuntimeError, match="verifier unavailable"):
        verify_android_purchase(ANDROID_MONTHLY, "tok-live-1")


def test_live_path_uses_fail_closed_parser(monkeypatch) -> None:
    _live_env(monkeypatch)
    monkeypatch.setattr(
        store,
        "_load_google_service_account",
        lambda: {
            "client_email": "svc@test.iam.gserviceaccount.com",
            "private_key": "-----BEGIN PRIVATE KEY-----\nTEST\n-----END PRIVATE KEY-----\n",
        },
    )
    monkeypatch.setattr(store, "_google_access_token", lambda _sa: "access-token")
    monkeypatch.setattr(store, "_google_fetch_subscription_v2", lambda *_a, **_k: _active_payload())
    purchase = verify_android_purchase(ANDROID_MONTHLY, "tok-live-1")
    assert purchase.status == "active"
    assert purchase.transaction_id == "GPA.1234-5678"


def test_entitlement_contract_aligns_with_google_live_statuses() -> None:
    """Mirror subscription_repository.is_premium gate used by android verify."""
    for status, expected in (
        ("active", True),
        ("trialing", True),
        ("grace_period", True),
        ("inactive", False),
        ("expired", False),
        ("canceled", False),
        ("refunded", False),
        ("unknown", False),
    ):
        assert (status in _premium_statuses()) is expected


def test_google_live_statuses_feed_entitlement_premium_gate() -> None:
    from app.models.subscription import VerifiedStorePurchase

    for state, expected_premium in (
        ("SUBSCRIPTION_STATE_ACTIVE", True),
        ("SUBSCRIPTION_STATE_IN_GRACE_PERIOD", True),
        ("SUBSCRIPTION_STATE_ON_HOLD", False),
        ("SUBSCRIPTION_STATE_PAUSED", False),
        ("SUBSCRIPTION_STATE_PENDING", False),
    ):
        purchase = verified_purchase_from_google_subscription(
            _active_payload(subscriptionState=state),
            package_name="com.hiair",
            product_id=ANDROID_MONTHLY,
            purchase_token=f"tok-{state}",
        )
        assert isinstance(purchase, VerifiedStorePurchase)
        assert (purchase.status in ("active", "trialing", "grace_period")) is expected_premium
