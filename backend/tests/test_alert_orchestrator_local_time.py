"""Quiet hours must use profile timezone, not UTC wall-clock."""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from app.models.air import (
    ProfileType,
    RecommendationCard,
    RiskAssessmentResult,
    RiskLevel,
    UserProfileContext,
)
from app.models.settings import UserSettingsResponse
from app.services.alert_orchestrator import evaluate_alert
from app.services.personal_load_engine import PersonalLoadInput


@pytest.fixture(autouse=True)
def _quiet_alert_side_effects(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.alert_orchestrator.air_repository.minutes_until_alert_cooldown_elapsed",
        lambda profile_id, cooldown_minutes=60, *, alert_type=None: 0,
    )
    monkeypatch.setattr(
        "app.services.alert_orchestrator.wearable_service.build_personal_load_input",
        lambda user_id, environment=None: PersonalLoadInput(consent_active=False),
    )
    monkeypatch.setattr(
        "app.services.alert_orchestrator.air_repository.find_recent_alert_by_dedupe_key",
        lambda dedupe_key, within_hours=4: False,
    )
    monkeypatch.setattr(
        "app.services.alert_orchestrator.air_repository.get_latest_risk_assessment",
        lambda _: {"overall_risk": "low"},
    )


def _profile(tz: str) -> UserProfileContext:
    return UserProfileContext(
        profile_id="profile-1",
        user_id="user-1",
        profile_type=ProfileType.ADULT_DEFAULT,
        age_group="adult",
        heat_sensitivity_level=2,
        respiratory_sensitivity_level=2,
        activity_level="moderate",
        timezone=tz,
        home_lat=40.7,
        home_lon=-74.0,
    )


def _risk() -> RiskAssessmentResult:
    return RiskAssessmentResult(
        overallRisk=RiskLevel.HIGH,
        heatRisk=RiskLevel.HIGH,
        airRisk=RiskLevel.HIGH,
        outdoorRisk=RiskLevel.HIGH,
        indoorVentilationRisk=RiskLevel.MODERATE,
        safeWindows=[],
        recommendationFlags=[],
        reasonCodes=["high_air"],
    )


def _card() -> RecommendationCard:
    return RecommendationCard(
        headline="Caution",
        summary="Limit outdoor time",
        actions=["Stay indoors"],
    )


def _settings() -> UserSettingsResponse:
    return UserSettingsResponse(
        user_id="user-1",
        push_alerts_enabled=True,
        alert_threshold="high",
        default_persona="adult",
        quiet_hours_start=22,
        quiet_hours_end=7,
        profile_based_alerting=True,
        preferred_language="en",
    )


def test_quiet_hours_not_applied_outside_local_night(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.alert_orchestrator.settings_repository.get_user_settings",
        lambda _: _settings(),
    )
    fixed = datetime(2026, 6, 15, 12, 0, tzinfo=ZoneInfo("UTC"))

    class _DT:
        @staticmethod
        def now(tz=None):
            return fixed.astimezone(tz) if tz is not None else fixed

    monkeypatch.setattr("app.services.alert_orchestrator.datetime", _DT)
    decision = evaluate_alert(_profile("America/New_York"), _risk(), _card(), language="en")
    assert decision.shouldSend is True
    assert decision.reason != "quiet_hours"


def test_quiet_hours_applied_in_local_night(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.alert_orchestrator.settings_repository.get_user_settings",
        lambda _: _settings(),
    )
    fixed = datetime(2026, 6, 15, 8, 0, tzinfo=ZoneInfo("UTC"))

    class _DT:
        @staticmethod
        def now(tz=None):
            return fixed.astimezone(tz) if tz is not None else fixed

    monkeypatch.setattr("app.services.alert_orchestrator.datetime", _DT)
    decision = evaluate_alert(_profile("America/New_York"), _risk(), _card(), language="en")
    assert decision.shouldSend is False
    assert decision.reason == "quiet_hours"
