"""Family caregiver risk overview — real per-profile risk, no synthesis."""

from __future__ import annotations

from datetime import UTC, datetime

import app.services.air_environment_service as air_environment_service
import app.services.air_repository as air_repository
import app.services.air_risk_engine as air_risk_engine
import app.services.family_repository as family_repository
import app.services.wearable_service as wearable_service
from app.models.air import RiskLevel
from app.models.family import FamilyMemberRiskLine, FamilyRiskOverviewResponse
from app.services.air_score import RISK_LEVEL_TO_SCORE
from app.services.forecast.mapping import forecast_to_hourly_inputs, overlay_forecast_current
from app.services.forecast.service import get_forecast

_RISK_ORDER = {
    RiskLevel.LOW: 0,
    RiskLevel.MODERATE: 1,
    RiskLevel.HIGH: 2,
    RiskLevel.VERY_HIGH: 3,
}


def _load_forecast_or_none(lat: float, lon: float):
    try:
        return get_forecast(lat, lon, force_refresh=False)
    except Exception:
        return None


def _assess_member_risk(*, owner_user_id: str, link) -> FamilyMemberRiskLine:
    profile = air_repository.get_profile_context(link.memberProfileId)
    if profile is None or profile.user_id != owner_user_id:
        return FamilyMemberRiskLine(
            memberLinkId=link.id,
            memberProfileId=link.memberProfileId,
            relation=link.relation,
            label=link.label,
            riskLevel=RiskLevel.MODERATE.value,
            riskScore=0,
            available=False,
            unavailableReason="profile_not_found",
        )
    try:
        environment = air_environment_service.load_environment(profile)
        forecast = _load_forecast_or_none(profile.home_lat, profile.home_lon)
        environment = overlay_forecast_current(environment, forecast)
        hourly_points = forecast_to_hourly_inputs(forecast) if forecast is not None else []
        personal_load = wearable_service.build_personal_load_input(owner_user_id, environment)
        risk = air_risk_engine.evaluate_risk(
            profile,
            environment,
            personal_load,
            hourly_points=hourly_points,
        )
        level = risk.overallRisk.value
        return FamilyMemberRiskLine(
            memberLinkId=link.id,
            memberProfileId=link.memberProfileId,
            relation=link.relation,
            label=link.label,
            riskLevel=level,
            riskScore=RISK_LEVEL_TO_SCORE.get(level, 45),
            available=True,
        )
    except Exception:
        return FamilyMemberRiskLine(
            memberLinkId=link.id,
            memberProfileId=link.memberProfileId,
            relation=link.relation,
            label=link.label,
            riskLevel=RiskLevel.MODERATE.value,
            riskScore=0,
            available=False,
            unavailableReason="environment_unavailable",
        )


def build_family_risk_overview(*, owner_user_id: str) -> FamilyRiskOverviewResponse:
    links = family_repository.list_members(owner_user_id=owner_user_id)
    lines = [_assess_member_risk(owner_user_id=owner_user_id, link=link) for link in links]
    highest: RiskLevel | None = None
    for line in lines:
        if not line.available:
            continue
        level = RiskLevel(line.riskLevel)
        if highest is None or _RISK_ORDER[level] > _RISK_ORDER[highest]:
            highest = level
    return FamilyRiskOverviewResponse(
        ownerUserId=owner_user_id,
        assessedAt=datetime.now(tz=UTC).isoformat(),
        members=lines,
        highestRiskLevel=highest.value if highest is not None else None,
    )
