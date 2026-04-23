from app.core.settings import settings
from app.models.air import DayPlanResponse, RiskAssessmentResult, RiskLevel
from app.services.observability import record_risk_level_alias


def normalize_legacy_level(level: str) -> str:
    normalized, _ = normalize_legacy_level_with_meta(level)
    return normalized


def normalize_legacy_level_with_meta(level: str) -> tuple[str, bool]:
    normalized = level.strip().lower()
    if normalized == "moderate":
        if settings.risk_level_alias_mode == "enforce":
            raise ValueError(
                "Legacy risk alias mapping moderate->medium is disabled in enforce mode."
            )
        record_risk_level_alias(domain="legacy", source_level="moderate", normalized_level="medium")
        return "medium", True
    return normalized, False


def normalize_air_risk(risk: RiskAssessmentResult) -> RiskAssessmentResult:
    return RiskAssessmentResult(
        overallRisk=_normalize_air_level(risk.overallRisk),
        heatRisk=_normalize_air_level(risk.heatRisk),
        airRisk=_normalize_air_level(risk.airRisk),
        outdoorRisk=_normalize_air_level(risk.outdoorRisk),
        indoorVentilationRisk=_normalize_air_level(risk.indoorVentilationRisk),
        safeWindows=risk.safeWindows,
        recommendationFlags=risk.recommendationFlags,
        reasonCodes=risk.reasonCodes,
    )


def normalize_day_plan(day_plan: DayPlanResponse) -> DayPlanResponse:
    return DayPlanResponse(
        profileId=day_plan.profileId,
        timezone=day_plan.timezone,
        hourlyRisk=[
            point.model_copy(update={"overallRisk": _normalize_air_level(point.overallRisk)})
            for point in day_plan.hourlyRisk
        ],
        safeWindows=day_plan.safeWindows,
        ventilationWindows=day_plan.ventilationWindows,
    )


def _normalize_air_level(level: RiskLevel) -> RiskLevel:
    if level == RiskLevel.MEDIUM:
        record_risk_level_alias(domain="air", source_level="medium", normalized_level="moderate")
        return RiskLevel.MODERATE
    return level
