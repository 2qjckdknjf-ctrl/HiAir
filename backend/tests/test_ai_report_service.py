from __future__ import annotations

from datetime import datetime, timezone
from types import SimpleNamespace

from app.models.air import (
    EnvironmentalInput,
    ProfileType,
    RecommendationCard,
    RiskAssessmentResult,
    RiskLevel,
    UserProfileContext,
)
import app.services.ai_report_service as ai_report_service


def _profile(timezone_name: str = "UTC") -> UserProfileContext:
    return UserProfileContext(
        profile_id="profile-1",
        user_id="user-1",
        profile_type=ProfileType.ADULT_DEFAULT,
        age_group="adult",
        heat_sensitivity_level=3,
        respiratory_sensitivity_level=3,
        activity_level="moderate",
        timezone=timezone_name,
        home_lat=41.39,
        home_lon=2.17,
    )


def _environment() -> EnvironmentalInput:
    return EnvironmentalInput(
        lat=41.39,
        lon=2.17,
        temperature=29.0,
        feels_like=31.0,
        humidity=55.0,
        aqi=72,
        pm25=18.0,
        pm10=22.0,
        ozone=65.0,
        uv=4.0,
        wind_speed=2.0,
        source="test",
        timestamp="2026-07-21T23:30:00+00:00",
        timezone="UTC",
    )


def _risk() -> RiskAssessmentResult:
    return RiskAssessmentResult(
        overallRisk=RiskLevel.MODERATE,
        heatRisk=RiskLevel.MODERATE,
        airRisk=RiskLevel.MODERATE,
        outdoorRisk=RiskLevel.MODERATE,
        indoorVentilationRisk=RiskLevel.MODERATE,
        safeWindows=[],
        recommendationFlags=[],
        reasonCodes=[],
        personalLoad=None,
    )


def _recommendation() -> RecommendationCard:
    return RecommendationCard(
        headline="Stay hydrated",
        summary="Air is manageable with lighter effort.",
        actions=["Take it easy"],
    )


def _patch_dependencies(monkeypatch, profile: UserProfileContext) -> None:
    monkeypatch.setattr(
        ai_report_service.air_repository, "get_profile_context", lambda _: profile
    )
    monkeypatch.setattr(
        ai_report_service.settings_repository,
        "get_user_settings",
        lambda _: SimpleNamespace(preferred_language="en"),
    )
    monkeypatch.setattr(
        ai_report_service.air_environment_service,
        "load_environment",
        lambda _: _environment(),
    )
    monkeypatch.setattr(
        ai_report_service.wearable_service,
        "build_personal_load_input",
        lambda *args, **kwargs: None,
    )
    monkeypatch.setattr(
        ai_report_service.air_risk_engine,
        "evaluate_risk",
        lambda *args, **kwargs: _risk(),
    )
    monkeypatch.setattr(
        ai_report_service.air_recommendation_engine,
        "generate_recommendation",
        lambda *args, **kwargs: _recommendation(),
    )
    monkeypatch.setattr(
        ai_report_service.wearable_service,
        "build_today_response",
        lambda _: SimpleNamespace(personalLoad=None),
    )


def test_local_date_uses_profile_timezone(monkeypatch) -> None:
    profile = _profile("Pacific/Kiritimati")
    _patch_dependencies(monkeypatch, profile)
    monkeypatch.setattr(
        ai_report_service, "_health_observations", lambda *args, **kwargs: []
    )
    monkeypatch.setattr(
        ai_report_service.ai_explanation_service,
        "generate_explanation",
        lambda *args, **kwargs: ("Air is manageable today.", "template_fallback"),
    )

    class FixedDateTime:
        @classmethod
        def now(cls, tz=None):
            return datetime(2026, 7, 21, 23, 30, tzinfo=timezone.utc)

    monkeypatch.setattr(ai_report_service, "datetime", FixedDateTime)

    report = ai_report_service.build_ai_report(
        user_id="user-1", profile_id="profile-1", kind="morning"
    )

    assert report["localDate"] == "2026-07-22"


def test_live_explanations_keep_kind_framing(monkeypatch) -> None:
    profile = _profile("UTC")
    _patch_dependencies(monkeypatch, profile)
    monkeypatch.setattr(
        ai_report_service, "_health_observations", lambda *args, **kwargs: []
    )
    monkeypatch.setattr(
        ai_report_service.ai_explanation_service,
        "generate_explanation",
        lambda *args, **kwargs: ("Keep activity lighter tonight.", "llm"),
    )

    report = ai_report_service.build_ai_report(
        user_id="user-1", profile_id="profile-1", kind="evening"
    )

    assert report["narrative"].startswith("Evening wrap-up:")
    assert "Keep activity lighter tonight." in report["narrative"]
