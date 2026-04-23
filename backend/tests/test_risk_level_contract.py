from app.core.settings import settings
from app.models.air import DayPlanResponse, HourlyRiskPoint, RiskAssessmentResult, RiskLevel
from app.services.risk_level_contract import (
    normalize_air_risk,
    normalize_day_plan,
    normalize_legacy_level,
    normalize_legacy_level_with_meta,
)


def test_normalize_legacy_level_maps_moderate_to_medium() -> None:
    assert normalize_legacy_level("moderate") == "medium"
    assert normalize_legacy_level("HIGH") == "high"


def test_normalize_legacy_level_with_meta_warn_mode() -> None:
    original = settings.risk_level_alias_mode
    try:
        object.__setattr__(settings, "risk_level_alias_mode", "warn")
        normalized, aliased = normalize_legacy_level_with_meta("moderate")
    finally:
        object.__setattr__(settings, "risk_level_alias_mode", original)
    assert normalized == "medium"
    assert aliased is True


def test_normalize_legacy_level_with_meta_enforce_mode_raises() -> None:
    original = settings.risk_level_alias_mode
    try:
        object.__setattr__(settings, "risk_level_alias_mode", "enforce")
        try:
            normalize_legacy_level_with_meta("moderate")
            raise AssertionError("Expected ValueError for enforce mode.")
        except ValueError:
            pass
    finally:
        object.__setattr__(settings, "risk_level_alias_mode", original)


def test_normalize_air_risk_maps_medium_to_moderate() -> None:
    risk = RiskAssessmentResult(
        overallRisk=RiskLevel.MEDIUM,
        heatRisk=RiskLevel.HIGH,
        airRisk=RiskLevel.MEDIUM,
        outdoorRisk=RiskLevel.LOW,
        indoorVentilationRisk=RiskLevel.MEDIUM,
        safeWindows=[],
        recommendationFlags=[],
        reasonCodes=[],
    )
    normalized = normalize_air_risk(risk)
    assert normalized.overallRisk == RiskLevel.MODERATE
    assert normalized.airRisk == RiskLevel.MODERATE
    assert normalized.indoorVentilationRisk == RiskLevel.MODERATE
    assert normalized.heatRisk == RiskLevel.HIGH


def test_normalize_day_plan_maps_hourly_medium_alias() -> None:
    day_plan = DayPlanResponse(
        profileId="p1",
        timezone="UTC",
        hourlyRisk=[HourlyRiskPoint(hour="10:00", overallRisk=RiskLevel.MEDIUM)],
        safeWindows=[],
        ventilationWindows=[],
    )
    normalized = normalize_day_plan(day_plan)
    assert normalized.hourlyRisk[0].overallRisk == RiskLevel.MODERATE
