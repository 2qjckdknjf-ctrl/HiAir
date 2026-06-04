"""Shared test fixtures — premium gates default to open unless a test overrides them."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from app.models.subscription import UserEntitlementResponse


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
        wearable_insights_enabled=False,
        priority_notifications_enabled=True,
    )


@pytest.fixture(autouse=True)
def _premium_entitlements_for_api_tests(monkeypatch: pytest.MonkeyPatch) -> None:
    import app.services.entitlement_service as entitlement_service

    def _premium(user_id: str) -> UserEntitlementResponse:
        return _premium_entitlement(user_id)

    monkeypatch.setattr(entitlement_service, "get_current_entitlement", _premium)
    monkeypatch.setattr(entitlement_service, "require_premium", lambda user_id, **kwargs: _premium(user_id))
    monkeypatch.setattr(
        entitlement_service,
        "require_feature",
        lambda user_id, feature, attr: _premium(user_id),
    )
    monkeypatch.setattr(entitlement_service, "assert_profile_limit", lambda user_id: None)
