from app.api import air as air_api
from app.api import dashboard as dashboard_api
from app.models.air import (
    EnvironmentalInput,
    ProfileType,
    RecommendationCard,
    RiskAssessmentResult,
    RiskLevel,
    UserProfileContext,
)
from app.models.forecast import (
    EnvironmentalDataKind,
    EnvironmentalForecast,
    EnvironmentalForecastPoint,
    ForecastFreshness,
    ForecastQuality,
    MetricProvenance,
)
from app.models.risk import EnvironmentSnapshot


def _profile() -> UserProfileContext:
    return UserProfileContext(
        profile_id="profile-1",
        user_id="user-1",
        profile_type=ProfileType.ADULT_DEFAULT,
        home_lat=41.39,
        home_lon=2.17,
        timezone="Europe/Madrid",
    )


def _environment() -> EnvironmentalInput:
    return EnvironmentalInput(
        lat=41.39,
        lon=2.17,
        temperature=22.0,
        feels_like=22.5,
        humidity=60.0,
        aqi=44,
        pm25=9.0,
        pm10=14.0,
        ozone=28.0,
        uv=3.0,
        wind_speed=1.5,
        source="cached",
        timestamp="2026-07-15T07:30:00+02:00",
        timezone="Europe/Madrid",
    )


def _snapshot() -> EnvironmentSnapshot:
    return EnvironmentSnapshot(
        temperature_c=22.0,
        humidity_percent=60.0,
        aqi=44,
        pm25=9.0,
        ozone=28.0,
        source="cached",
        pm10=14.0,
        uv=3.0,
        wind_speed=1.5,
        feels_like=22.5,
        timezone="Europe/Madrid",
    )


def _forecast() -> EnvironmentalForecast:
    return EnvironmentalForecast(
        current=EnvironmentalForecastPoint(
            timestamp="2026-07-15T08:00:00+02:00",
            timezone="Europe/Madrid",
            lat=41.39,
            lon=2.17,
            temperature_c=24.0,
            apparent_temperature_c=25.0,
            relative_humidity_pct=None,
            wind_speed_mps=None,
            uv_index=None,
            aqi=None,
            pm25_ugm3=None,
            pm10_ugm3=None,
            ozone_ugm3=None,
            provenance=MetricProvenance(
                provider="openmeteo",
                product="test",
                observed_at="2026-07-15T08:00:00+02:00",
                fetched_at="2026-07-15T08:00:00+02:00",
                kind=EnvironmentalDataKind.FORECAST,
            ),
            missing_metrics=["relative_humidity_pct", "aqi", "pm25_ugm3", "ozone_ugm3"],
            quality=ForecastQuality.PARTIAL,
        ),
        hourly=[],
        timezone="Europe/Madrid",
        lat=41.39,
        lon=2.17,
        generated_at="2026-07-15T08:00:00+02:00",
        fetched_at="2026-07-15T08:00:00+02:00",
        freshness=ForecastFreshness.LIVE,
        quality=ForecastQuality.PARTIAL,
        sources=["openmeteo"],
        missing_metrics=["aqi"],
        provider_summary="partial current",
    )


def _risk() -> RiskAssessmentResult:
    return RiskAssessmentResult(
        overallRisk=RiskLevel.MODERATE,
        heatRisk=RiskLevel.MODERATE,
        airRisk=RiskLevel.LOW,
        outdoorRisk=RiskLevel.MODERATE,
        indoorVentilationRisk=RiskLevel.LOW,
        safeWindows=[],
        recommendationFlags=[],
        reasonCodes=[],
    )


def _recommendation() -> RecommendationCard:
    return RecommendationCard(
        headline="Stay aware",
        summary="Conditions are manageable.",
        actions=["Hydrate"],
    )


def test_compute_and_persist_preserves_air_metrics_on_partial_current(monkeypatch) -> None:
    profile = _profile()
    saved = {}

    monkeypatch.setattr(air_api, "_resolve_profile_for_user", lambda profile_id, user_id: profile)
    monkeypatch.setattr(
        air_api.settings_repository,
        "get_user_settings",
        lambda user_id: type("Settings", (), {"preferred_language": "en"})(),
    )
    monkeypatch.setattr(air_api.air_environment_service, "load_environment", lambda profile, **kwargs: _environment())
    monkeypatch.setattr(air_api, "_load_forecast_or_none", lambda *args, **kwargs: _forecast())
    monkeypatch.setattr(air_api.wearable_service, "build_personal_load_input", lambda user_id, environment: None)
    monkeypatch.setattr(air_api.air_risk_engine, "evaluate_risk", lambda *args, **kwargs: _risk())
    monkeypatch.setattr(
        air_api.air_recommendation_engine,
        "generate_recommendation",
        lambda profile, risk, language: _recommendation(),
    )
    monkeypatch.setattr(
        air_api.ai_explanation_service,
        "generate_explanation",
        lambda *args, **kwargs: ("Use safer windows.", "template"),
    )

    def _save_environment(environment):
        saved["environment"] = environment
        return "snapshot-1"

    monkeypatch.setattr(air_api.air_repository, "save_environment_snapshot", _save_environment)
    monkeypatch.setattr(air_api.air_repository, "save_risk_assessment", lambda *args, **kwargs: "assessment-1")
    monkeypatch.setattr(air_api.air_repository, "save_recommendation", lambda *args, **kwargs: None)

    response = air_api._compute_and_persist("profile-1", "user-1", force_live=False)
    assert response.environmental.temperature == 24.0
    assert response.environmental.feels_like == 25.0
    assert response.environmental.humidity == 60.0
    assert response.environmental.aqi == 44
    assert response.environmental.pm25 == 9.0
    assert response.environmental.ozone == 28.0
    assert response.environmental.source == "cached"
    assert saved["environment"].aqi == 44


def test_recommendations_preserve_air_metrics_on_partial_current(monkeypatch) -> None:
    profile = _profile()
    seen = {}

    monkeypatch.setattr(air_api, "_resolve_profile_for_user", lambda profile_id, user_id: profile)
    monkeypatch.setattr(
        air_api.settings_repository,
        "get_user_settings",
        lambda user_id: type("Settings", (), {"preferred_language": "en"})(),
    )
    monkeypatch.setattr(air_api.air_environment_service, "load_environment", lambda profile, **kwargs: _environment())
    monkeypatch.setattr(air_api, "_load_forecast_or_none", lambda *args, **kwargs: _forecast())
    monkeypatch.setattr(air_api.wearable_service, "build_personal_load_input", lambda user_id, environment: None)

    def _evaluate(profile, environment, personal_load, hourly_points=None):
        seen["environment"] = environment
        return _risk()

    monkeypatch.setattr(air_api.air_risk_engine, "evaluate_risk", _evaluate)
    monkeypatch.setattr(
        air_api.air_recommendation_engine,
        "generate_recommendation",
        lambda profile, risk, language: _recommendation(),
    )

    response = air_api.get_recommendations("profile-1", "user-1")
    assert response.generatedAt == "2026-07-15T08:00:00+02:00"
    assert seen["environment"].aqi == 44
    assert seen["environment"].pm25 == 9.0
    assert seen["environment"].ozone == 28.0
    assert seen["environment"].source == "cached"


def test_dashboard_overview_preserves_air_metrics_on_partial_current(monkeypatch) -> None:
    monkeypatch.setattr(dashboard_api.air_environment_service, "resolve_environment_snapshot", lambda **kwargs: _snapshot())
    monkeypatch.setattr(dashboard_api, "_forecast_bundle", lambda lat, lon: _forecast())
    monkeypatch.setattr(dashboard_api.wearable_service, "build_personal_load_input", lambda user_id, environment: None)
    monkeypatch.setattr(dashboard_api.air_risk_engine, "evaluate_risk", lambda *args, **kwargs: _risk())
    monkeypatch.setattr(
        dashboard_api.settings_repository,
        "get_user_settings",
        lambda user_id: type("Settings", (), {"preferred_language": "en"})(),
    )
    monkeypatch.setattr(
        dashboard_api.air_recommendation_engine,
        "generate_recommendation",
        lambda profile, risk, language: _recommendation(),
    )
    monkeypatch.setattr(
        dashboard_api.recommendation_service,
        "build_daily_recommendation",
        lambda **kwargs: ("Low concern today", ["Hydrate"]),
    )
    monkeypatch.setattr(dashboard_api.notification_service, "should_notify", lambda risk: False)
    monkeypatch.setattr(dashboard_api.notification_service, "build_notification_text", lambda risk: "No alert")

    response = dashboard_api.dashboard_overview(None, "adult", 41.39, 2.17, "user-1")
    assert response.environment.temperature_c == 24.0
    assert response.environment.humidity_percent == 60.0
    assert response.environment.aqi == 44
    assert response.environment.pm25 == 9.0
    assert response.environment.ozone == 28.0
    assert response.environment.source == "cached"
