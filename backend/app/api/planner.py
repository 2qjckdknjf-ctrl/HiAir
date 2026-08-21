from fastapi import APIRouter, Depends, HTTPException, Query
from app.api.deps import get_current_user_id
import app.services.entitlement_service as entitlement_service

from app.models.air import SafeWindowType, UserProfileContext
from app.models.planner import DailyPlannerResponse, HourlyRiskItem, SafeWindow
from app.services.air_repository import PERSONA_TO_PROFILE_TYPE
from app.services.air_score import RISK_LEVEL_TO_SCORE
import app.services.air_environment_service as air_environment_service
import app.services.air_risk_engine as air_risk_engine
from app.services.forecast.mapping import forecast_to_hourly_inputs
from app.services.forecast.service import get_forecast

router = APIRouter(prefix="/planner", tags=["planner"])


def _normalize_persona(value: str) -> str:
    normalized = value.lower()
    return normalized if normalized in PERSONA_TO_PROFILE_TYPE else "adult"


@router.get("/daily", response_model=DailyPlannerResponse)
def daily_planner(
    persona: str = Query(default="adult"),
    lat: float = Query(default=41.39, ge=-90, le=90),
    lon: float = Query(default=2.17, ge=-180, le=180),
    hours: int = Query(default=12, ge=6, le=24),
    user_id: str = Depends(get_current_user_id),
) -> DailyPlannerResponse:
    entitlement_service.require_feature(user_id, "extended_forecast", "extended_forecast_enabled")
    normalized_persona = _normalize_persona(persona)
    profile_context = UserProfileContext(
        profile_id=f"planner-virtual-{user_id}",
        user_id=user_id,
        profile_type=PERSONA_TO_PROFILE_TYPE[normalized_persona],
        age_group=normalized_persona,
        home_lat=lat,
        home_lon=lon,
    )
    try:
        air_environment_service.load_environment(profile_context)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail="Environmental data unavailable") from exc

    try:
        forecast = get_forecast(lat, lon, hours=max(24, hours))
    except RuntimeError:
        return DailyPlannerResponse(
            persona=normalized_persona,
            base_lat=lat,
            base_lon=lon,
            hourly=[],
            safe_windows=[],
            timezone=profile_context.timezone,
            dataQuality="unavailable",
            forecastAvailable=False,
        )

    hourly_inputs = forecast_to_hourly_inputs(forecast, max_hours=hours)
    hourly: list[HourlyRiskItem] = []
    for slot in hourly_inputs:
        risk = air_risk_engine.evaluate_risk(profile_context, slot, hourly_points=[])
        level = risk.overallRisk.value
        hourly.append(
            HourlyRiskItem(
                hour_iso=slot.timestamp,
                score=RISK_LEVEL_TO_SCORE[level],
                level=level,
            )
        )

    # Same outdoor gate as day-plan — never treat air-unknown "moderate" as a safe window.
    engine_windows = air_risk_engine._build_safe_windows_from_hourly(profile_context, hourly_inputs)
    safe_windows = [
        SafeWindow(start_hour_iso=window.start, end_hour_iso=window.end)
        for window in engine_windows
        if window.type == SafeWindowType.GENERAL_OUTDOOR
    ]

    return DailyPlannerResponse(
        persona=normalized_persona,
        base_lat=lat,
        base_lon=lon,
        hourly=hourly,
        safe_windows=safe_windows,
        timezone=forecast.timezone,
        dataQuality=forecast.quality.value,
        freshness=forecast.freshness.value,
        sources=forecast.sources,
        forecastAvailable=len(hourly) > 0,
    )
