from app.models.air import DayPlanResponse, HourlyRiskPoint, RiskAssessmentResult, RiskLevel
from app.services.risk_level_contract import normalize_air_risk, normalize_day_plan, normalize_legacy_level


def test_normalize_legacy_level_maps_moderate_to_medium() -> None:
    assert normalize_legacy_level("moderate") == "medium"
    assert normalize_legacy_level("HIGH") == "high"


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
