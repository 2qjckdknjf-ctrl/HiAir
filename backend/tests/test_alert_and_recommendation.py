from app.models.air import (
    AlertSeverity,
    ProfileType,
    RecommendationCard,
    RiskAssessmentResult,
    RiskLevel,
    SafeWindow,
    SafeWindowType,
    UserProfileContext,
)
from app.models.settings import UserSettingsResponse
from app.services.air_recommendation_engine import generate_recommendation
from app.services.alert_orchestrator import evaluate_alert


def build_profile(profile_type: ProfileType = ProfileType.ADULT_DEFAULT) -> UserProfileContext:
    return UserProfileContext(
        profile_id="profile-1",
        user_id="user-1",
        profile_type=profile_type,
        age_group="adult",
        heat_sensitivity_level=2,
        respiratory_sensitivity_level=2,
        activity_level="moderate",
        timezone="UTC",
        home_lat=41.39,
        home_lon=2.17,
    )


def build_risk(level: RiskLevel) -> RiskAssessmentResult:
    return RiskAssessmentResult(
        overallRisk=level,
        heatRisk=level,
        airRisk=level,
        outdoorRisk=level,
        indoorVentilationRisk=level,
        safeWindows=[
            SafeWindow(
                type=SafeWindowType.VENTILATION,
                start="2026-04-07T20:00:00+00:00",
                end="2026-04-07T22:00:00+00:00",
                confidence=0.8,
            )
        ],
        recommendationFlags=["ventilate_later"] if level != RiskLevel.LOW else [],
        reasonCodes=["high_heat"] if level != RiskLevel.LOW else [],
    )


def test_recommendation_returns_actionable_card() -> None:
    card = generate_recommendation(build_profile(ProfileType.CHILD), build_risk(RiskLevel.HIGH))
    assert isinstance(card, RecommendationCard)
    assert card.headline != ""
    assert len(card.actions) >= 1
    assert len(card.actions) <= 3


def test_recommendation_supports_english_language() -> None:
    card = generate_recommendation(build_profile(ProfileType.ADULT_DEFAULT), build_risk(RiskLevel.MODERATE), language="en")
    assert "safer" in card.headline.lower() or "conditions" in card.summary.lower()


def test_alert_evaluate_respects_dedup(monkeypatch) -> None:
    def fake_settings(_: str) -> UserSettingsResponse:
        return UserSettingsResponse(
            user_id="user-1",
            push_alerts_enabled=True,
            alert_threshold="high",
            default_persona="adult",
            quiet_hours_start=23,
            quiet_hours_end=6,
            profile_based_alerting=True,
            preferred_language="ru",
        )

    monkeypatch.setattr("app.services.alert_orchestrator.settings_repository.get_user_settings", fake_settings)
    monkeypatch.setattr(
        "app.services.alert_orchestrator.air_repository.get_latest_risk_assessment",
        lambda _: {"overall_risk": "moderate"},
    )
    monkeypatch.setattr(
        "app.services.alert_orchestrator.air_repository.find_recent_alert_by_dedupe_key",
        lambda dedupe_key, within_hours=4: True,
    )
    monkeypatch.setattr(
        "app.services.alert_orchestrator._is_quiet_hours",
        lambda start_hour, end_hour, now_hour: False,
    )

    decision = evaluate_alert(
        build_profile(),
        build_risk(RiskLevel.HIGH),
        RecommendationCard(headline="h", summary="s", actions=["a"]),
    )
    assert decision.shouldSend is False
    assert decision.reason == "deduplicated"


def test_alert_high_risk_returns_high_severity(monkeypatch) -> None:
    def fake_settings(_: str) -> UserSettingsResponse:
        return UserSettingsResponse(
            user_id="user-1",
            push_alerts_enabled=True,
            alert_threshold="high",
            default_persona="adult",
            quiet_hours_start=23,
            quiet_hours_end=6,
            profile_based_alerting=True,
            preferred_language="ru",
        )

    monkeypatch.setattr("app.services.alert_orchestrator.settings_repository.get_user_settings", fake_settings)
    monkeypatch.setattr(
        "app.services.alert_orchestrator.air_repository.get_latest_risk_assessment",
        lambda _: {"overall_risk": "low"},
    )
    monkeypatch.setattr(
        "app.services.alert_orchestrator.air_repository.find_recent_alert_by_dedupe_key",
        lambda dedupe_key, within_hours=4: False,
    )
    monkeypatch.setattr(
        "app.services.alert_orchestrator._is_quiet_hours",
        lambda start_hour, end_hour, now_hour: False,
    )

    decision = evaluate_alert(
        build_profile(ProfileType.ASTHMA_SENSITIVE),
        build_risk(RiskLevel.HIGH),
        RecommendationCard(headline="h", summary="s", actions=["a"]),
    )
    assert decision.shouldSend is True
    assert decision.severity == AlertSeverity.HIGH


def test_recommendation_supports_moderate_level() -> None:
    card = generate_recommendation(
        build_profile(ProfileType.ADULT_DEFAULT),
        build_risk(RiskLevel.MODERATE),
        language="en",
    )
    assert "safer" in card.headline.lower() or "conditions" in card.summary.lower()


def test_alert_legacy_medium_history_maps_to_medium_severity(monkeypatch) -> None:
    def fake_settings(_: str) -> UserSettingsResponse:
        return UserSettingsResponse(
            user_id="user-1",
            push_alerts_enabled=True,
            alert_threshold="medium",
            default_persona="adult",
            quiet_hours_start=23,
            quiet_hours_end=6,
            profile_based_alerting=True,
            preferred_language="en",
        )

    monkeypatch.setattr("app.services.alert_orchestrator.settings_repository.get_user_settings", fake_settings)
    monkeypatch.setattr(
        "app.services.alert_orchestrator.air_repository.get_latest_risk_assessment",
        lambda _: {"overall_risk": "medium"},
    )
    monkeypatch.setattr(
        "app.services.alert_orchestrator.air_repository.find_recent_alert_by_dedupe_key",
        lambda dedupe_key, within_hours=4: False,
    )
    monkeypatch.setattr(
        "app.services.alert_orchestrator._is_quiet_hours",
        lambda start_hour, end_hour, now_hour: False,
    )

    decision = evaluate_alert(
        build_profile(ProfileType.ADULT_DEFAULT),
        build_risk(RiskLevel.MODERATE),
        RecommendationCard(headline="h", summary="s", actions=["a"]),
    )
    assert decision.shouldSend is False
    assert decision.reason == "no_material_change"
    assert decision.severity is None
