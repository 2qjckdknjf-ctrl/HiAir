"""Security regression tests for live Apple JWS subscription verification."""

from __future__ import annotations

import base64
import hashlib
import json
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest

from app.services import subscription_store as store
from app.services.subscription_store import (
    IOS_MONTHLY,
    IOS_YEARLY,
    build_stub_ios_jws,
    build_unsigned_ios_jws,
    verify_ios_purchase,
)


def _b64(data: dict) -> str:
    return base64.urlsafe_b64encode(json.dumps(data).encode()).decode().rstrip("=")


def _active_payload(**overrides) -> dict:
    payload = {
        "bundleId": "com.hiair.app",
        "environment": "Sandbox",
        "productId": IOS_MONTHLY,
        "transactionId": "tx-live-1",
        "originalTransactionId": "orig-live-1",
        "expiresDate": int((datetime.now(tz=UTC) + timedelta(days=30)).timestamp() * 1000),
        "status": "active",
    }
    payload.update(overrides)
    return payload


def test_live_rejects_alg_none(monkeypatch) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "live")
    monkeypatch.setenv("APPLE_STORE_ENVIRONMENT", "sandbox")
    monkeypatch.setenv("APPLE_BUNDLE_ID", "com.hiair.app")
    jws = build_stub_ios_jws(IOS_MONTHLY)
    with pytest.raises((ValueError, RuntimeError)):
        verify_ios_purchase(jws, product_id=IOS_MONTHLY)


def test_live_rejects_tampered_payload_after_signature(monkeypatch) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "live")
    monkeypatch.setenv("APPLE_STORE_ENVIRONMENT", "sandbox")
    monkeypatch.setenv("APPLE_BUNDLE_ID", "com.hiair.app")

    good = _active_payload()
    header = _b64({"alg": "ES256", "x5c": ["deadbeef"]})
    body = _b64(good)
    # Fake signature bytes — library / crypto path must reject.
    signed = f"{header}.{body}.not-a-real-signature"

    # Tamper payload after "signing"
    tampered_body = _b64({**good, "productId": IOS_YEARLY})
    tampered = f"{header}.{tampered_body}.not-a-real-signature"

    with pytest.raises((ValueError, RuntimeError)):
        verify_ios_purchase(tampered, product_id=IOS_MONTHLY)
    with pytest.raises((ValueError, RuntimeError)):
        verify_ios_purchase(signed, product_id=IOS_MONTHLY)


def test_live_rejects_corrupted_signature(monkeypatch) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "live")
    monkeypatch.setenv("APPLE_STORE_ENVIRONMENT", "sandbox")
    payload = _active_payload()
    jws = f"{_b64({'alg': 'ES256'})}.{_b64(payload)}.corrupt"
    with pytest.raises((ValueError, RuntimeError)):
        verify_ios_purchase(jws, product_id=IOS_MONTHLY)


def test_live_rejects_wrong_bundle_id(monkeypatch) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "live")
    monkeypatch.setenv("APPLE_STORE_ENVIRONMENT", "sandbox")
    monkeypatch.setenv("APPLE_BUNDLE_ID", "com.hiair.app")

    def _decode(signed_transaction: str, cfg):  # noqa: ANN001
        return _active_payload(bundleId="com.attacker.app")

    monkeypatch.setattr(store, "_apple_transaction_decoder", _decode)
    with pytest.raises(ValueError, match="bundle ID"):
        verify_ios_purchase("hdr.payload.sig", product_id=IOS_MONTHLY)


def test_live_rejects_wrong_environment(monkeypatch) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "live")
    monkeypatch.setenv("APPLE_STORE_ENVIRONMENT", "sandbox")
    monkeypatch.setenv("APPLE_BUNDLE_ID", "com.hiair.app")

    def _decode(signed_transaction: str, cfg):  # noqa: ANN001
        return _active_payload(environment="Production")

    monkeypatch.setattr(store, "_apple_transaction_decoder", _decode)
    with pytest.raises(ValueError, match="environment"):
        verify_ios_purchase("hdr.payload.sig", product_id=IOS_MONTHLY)


def test_live_rejects_unknown_product(monkeypatch) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "live")
    monkeypatch.setenv("APPLE_STORE_ENVIRONMENT", "sandbox")
    monkeypatch.setenv("APPLE_BUNDLE_ID", "com.hiair.app")

    def _decode(signed_transaction: str, cfg):  # noqa: ANN001
        return _active_payload(productId="com.hiair.premium.unknown")

    monkeypatch.setattr(store, "_apple_transaction_decoder", _decode)
    with pytest.raises(ValueError, match="Unknown store product"):
        verify_ios_purchase("hdr.payload.sig", product_id="com.hiair.premium.unknown")


def test_live_expired_and_revoked_not_active_premium(monkeypatch) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "live")
    monkeypatch.setenv("APPLE_STORE_ENVIRONMENT", "sandbox")
    monkeypatch.setenv("APPLE_BUNDLE_ID", "com.hiair.app")

    expired_ms = int((datetime.now(tz=UTC) - timedelta(days=2)).timestamp() * 1000)

    def _expired(signed_transaction: str, cfg):  # noqa: ANN001
        return _active_payload(expiresDate=expired_ms)

    monkeypatch.setattr(store, "_apple_transaction_decoder", _expired)
    expired = verify_ios_purchase("hdr.payload.sig", product_id=IOS_MONTHLY)
    assert expired.status == "expired"
    assert expired.status not in ("active", "trialing", "grace_period")

    def _revoked(signed_transaction: str, cfg):  # noqa: ANN001
        return _active_payload(revocationDate=expired_ms, revocationReason=1)

    monkeypatch.setattr(store, "_apple_transaction_decoder", _revoked)
    revoked = verify_ios_purchase("hdr.payload.sig", product_id=IOS_MONTHLY)
    assert revoked.status == "refunded"
    assert revoked.status not in ("active", "trialing", "grace_period")


def test_live_verified_fixture_maps_entitlement(monkeypatch) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "live")
    monkeypatch.setenv("APPLE_STORE_ENVIRONMENT", "sandbox")
    monkeypatch.setenv("APPLE_BUNDLE_ID", "com.hiair.app")

    def _decode(signed_transaction: str, cfg):  # noqa: ANN001
        assert cfg.apple_bundle_id == "com.hiair.app"
        return _active_payload()

    monkeypatch.setattr(store, "_apple_transaction_decoder", _decode)
    purchase = verify_ios_purchase("hdr.payload.sig", product_id=IOS_MONTHLY)
    assert purchase.status == "active"
    assert purchase.product_id == IOS_MONTHLY
    assert purchase.plan_id == "premium_monthly"
    assert purchase.provider == "apple"
    assert purchase.transaction_id == "tx-live-1"
    assert purchase.original_transaction_id == "orig-live-1"


def test_live_verifier_unavailable_does_not_grant_premium(monkeypatch) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "live")
    monkeypatch.setenv("APPLE_STORE_ENVIRONMENT", "sandbox")
    monkeypatch.setenv("APPLE_BUNDLE_ID", "com.hiair.app")
    monkeypatch.setattr(store, "_apple_transaction_decoder", None)

    def _boom(*_args, **_kwargs):  # noqa: ANN001
        raise RuntimeError("certs missing")

    monkeypatch.setattr(store, "_build_apple_signed_data_verifier", _boom)
    jws = build_unsigned_ios_jws(_active_payload(), alg="ES256")
    with pytest.raises(RuntimeError, match="unavailable"):
        verify_ios_purchase(jws, product_id=IOS_MONTHLY)


def test_live_never_falls_back_to_stub_decode(monkeypatch) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "live")
    monkeypatch.setenv("APPLE_STORE_ENVIRONMENT", "sandbox")
    # alg=none stub token that stub mode would accept:
    jws = build_stub_ios_jws(IOS_MONTHLY)
    with pytest.raises((ValueError, RuntimeError)):
        verify_ios_purchase(jws, product_id=IOS_MONTHLY)


def test_stub_mode_still_accepts_test_helper(monkeypatch) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "stub")
    purchase = verify_ios_purchase(build_stub_ios_jws(IOS_MONTHLY), product_id=IOS_MONTHLY)
    assert purchase.status == "active"


@pytest.mark.parametrize(
    "missing_field",
    [
        "bundleId",
        "environment",
        "productId",
        "transactionId",
        "originalTransactionId",
        "expiresDate",
    ],
)
def test_live_rejects_missing_required_field(monkeypatch, missing_field: str) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "live")
    monkeypatch.setenv("APPLE_STORE_ENVIRONMENT", "sandbox")
    monkeypatch.setenv("APPLE_BUNDLE_ID", "com.hiair.app")

    def _decode(signed_transaction: str, cfg):  # noqa: ANN001
        payload = _active_payload()
        payload.pop(missing_field, None)
        return payload

    monkeypatch.setattr(store, "_apple_transaction_decoder", _decode)
    with pytest.raises(ValueError, match="missing required field"):
        verify_ios_purchase("hdr.payload.sig", product_id=IOS_MONTHLY)


def test_live_rejects_unknown_store_environment_config(monkeypatch) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "live")
    monkeypatch.setenv("APPLE_STORE_ENVIRONMENT", "not-a-real-env")
    monkeypatch.setenv("APPLE_BUNDLE_ID", "com.hiair.app")

    def _decode(signed_transaction: str, cfg):  # noqa: ANN001
        return _active_payload()

    monkeypatch.setattr(store, "_apple_transaction_decoder", _decode)
    with pytest.raises(RuntimeError, match="Unknown APPLE_STORE_ENVIRONMENT"):
        verify_ios_purchase("hdr.payload.sig", product_id=IOS_MONTHLY)


def test_live_does_not_synthesize_expires_or_transaction_hash(monkeypatch) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "live")
    monkeypatch.setenv("APPLE_STORE_ENVIRONMENT", "sandbox")
    monkeypatch.setenv("APPLE_BUNDLE_ID", "com.hiair.app")

    def _decode(signed_transaction: str, cfg):  # noqa: ANN001
        payload = _active_payload()
        payload.pop("expiresDate")
        payload.pop("transactionId")
        return payload

    monkeypatch.setattr(store, "_apple_transaction_decoder", _decode)
    with pytest.raises(ValueError, match="missing required field"):
        verify_ios_purchase("hdr.payload.sig", product_id=IOS_MONTHLY)


def test_live_production_requires_app_apple_id(monkeypatch) -> None:
    monkeypatch.setenv("APPLE_STORE_VERIFIER_MODE", "live")
    monkeypatch.setenv("APPLE_STORE_ENVIRONMENT", "production")
    monkeypatch.setenv("APPLE_BUNDLE_ID", "com.hiair.app")
    monkeypatch.delenv("APPLE_APP_APPLE_ID", raising=False)
    monkeypatch.setattr(store, "_apple_transaction_decoder", None)

    jws = build_unsigned_ios_jws(_active_payload(environment="Production"), alg="ES256")
    with pytest.raises(RuntimeError):
        verify_ios_purchase(jws, product_id=IOS_MONTHLY)
