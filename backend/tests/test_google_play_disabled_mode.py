"""Fail-closed Google Play verifier disabled mode."""

from __future__ import annotations

import importlib.util
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api import deps
from app.api import subscriptions as subscriptions_api
from app.main import app
from app.services import subscription_store
from app.services.subscription_store import (
    ANDROID_MONTHLY,
    GOOGLE_PLAY_DISABLED_DETAIL,
    GooglePlayVerifierDisabledError,
    verify_android_purchase,
)

ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend"


def _load_check_env_security():
    path = BACKEND / "scripts" / "check_env_security.py"
    spec = importlib.util.spec_from_file_location("check_env_security", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _auth_headers() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def _prod_base_env(**overrides: str) -> dict[str, str]:
    base = {
        "APP_ENV": "production",
        "JWT_SECRET": "x" * 32,
        "DATABASE_URL": "postgresql://hiair:hiair@localhost:5432/hiair",
        "APPLE_STORE_VERIFIER_MODE": "live",
        "APPLE_STORE_ENVIRONMENT": "production",
        "APPLE_APP_APPLE_ID": "6773610034",
        "HIAIR_ALLOW_INSECURE_LOCAL_DEV": "false",
        "SUBSCRIPTION_PROVIDER": "apple",
        "SUBSCRIPTION_WEBHOOK_SECRET": "webhook-secret-16+",
        "NOTIFICATIONS_PROVIDER_MODE": "stub",
        "NOTIFICATION_ADMIN_TOKEN": "notification-admin-token-16",
        "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK": "false",
        "HIAIR_AUTH_PROVIDER": "supabase",
        "GOOGLE_PLAY_PACKAGE_NAME": "com.hiair",
    }
    base.update(overrides)
    return base


def _auth_ok(monkeypatch: pytest.MonkeyPatch, user_id: str = "user-disabled-1") -> None:
    monkeypatch.setattr(deps, "decode_access_token", lambda token: user_id)
    monkeypatch.setattr(deps.user_repository, "user_exists", lambda user_id: True)


def test_protected_google_stub_fails() -> None:
    module = _load_check_env_security()
    results = module._run_checks(_prod_base_env(GOOGLE_PLAY_VERIFIER_MODE="stub"))
    errors = [item.message for item in results if item.level == "ERROR"]
    assert any("GOOGLE_PLAY_VERIFIER_MODE=stub" in msg for msg in errors)


def test_protected_google_disabled_passes_without_service_account() -> None:
    module = _load_check_env_security()
    results = module._run_checks(_prod_base_env(GOOGLE_PLAY_VERIFIER_MODE="disabled"))
    errors = [item.message for item in results if item.level == "ERROR"]
    assert not any("GOOGLE_PLAY" in msg for msg in errors)
    warnings = [item.message for item in results if item.level == "WARN"]
    assert not any("GOOGLE_PLAY_VERIFIER_MODE=disabled" in msg for msg in warnings)
    oks = [item.message for item in results if item.level == "OK"]
    assert any("GOOGLE_PLAY_VERIFIER_MODE=disabled" in msg for msg in oks)


def test_protected_google_live_without_service_account_fails() -> None:
    module = _load_check_env_security()
    results = module._run_checks(_prod_base_env(GOOGLE_PLAY_VERIFIER_MODE="live"))
    errors = [item.message for item in results if item.level == "ERROR"]
    assert any("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" in msg for msg in errors)


def test_disabled_verify_raises_without_google_call(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("GOOGLE_PLAY_VERIFIER_MODE", "disabled")
    called = {"live": False}

    def _boom(*_a, **_k):
        called["live"] = True
        raise AssertionError("live verifier must not run")

    monkeypatch.setattr(subscription_store, "_verify_google_play_live", _boom)
    with pytest.raises(GooglePlayVerifierDisabledError) as exc:
        verify_android_purchase(ANDROID_MONTHLY, "any-token")
    assert str(exc.value) == GOOGLE_PLAY_DISABLED_DETAIL
    assert called["live"] is False


def test_disabled_verify_api_returns_503_no_entitlement(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("GOOGLE_PLAY_VERIFIER_MODE", "disabled")
    _auth_ok(monkeypatch)
    apply = MagicMock(return_value=SimpleNamespace(user_id="x", status="none", entitlement=None))
    monkeypatch.setattr(subscriptions_api.subscription_repository, "apply_verified_purchase", apply)
    client = TestClient(app)
    response = client.post(
        "/api/subscriptions/android/verify",
        json={"product_id": ANDROID_MONTHLY, "purchase_token": "tok-disabled-1"},
        headers=_auth_headers(),
    )
    assert response.status_code == 503
    assert response.json()["detail"] == GOOGLE_PLAY_DISABLED_DETAIL
    assert apply.call_count == 0


def test_disabled_restore_api_returns_503_no_entitlement(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("GOOGLE_PLAY_VERIFIER_MODE", "disabled")
    _auth_ok(monkeypatch, "user-disabled-2")
    apply = MagicMock()
    monkeypatch.setattr(subscriptions_api.subscription_repository, "apply_verified_purchase", apply)
    client = TestClient(app)
    response = client.post(
        "/api/subscriptions/restore",
        json={
            "platform": "android",
            "ios_signed_transactions": [],
            "android_purchases": [
                {"product_id": ANDROID_MONTHLY, "purchase_token": "tok-disabled-2"},
            ],
        },
        headers=_auth_headers(),
    )
    assert response.status_code == 503
    assert response.json()["detail"] == GOOGLE_PLAY_DISABLED_DETAIL
    assert apply.call_count == 0


def test_disabled_google_webhook_returns_503(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("GOOGLE_PLAY_VERIFIER_MODE", "disabled")
    monkeypatch.setenv("SUBSCRIPTION_WEBHOOK_SECRET", "webhook-secret-16+")
    client = TestClient(app)
    response = client.post(
        "/api/subscriptions/webhook/google",
        json={"message": {"data": "e30="}},
        headers={"X-Goog-Channel-Token": "unused"},
    )
    assert response.status_code == 503
    assert response.json()["detail"] == GOOGLE_PLAY_DISABLED_DETAIL
