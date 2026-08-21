from fastapi import APIRouter, Depends, HTTPException, Query
from app.api.deps import get_current_user_id
import app.services.entitlement_service as entitlement_service

from app.models.air import UserProfileContext
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

    hourly_inputs = forecast_to_hourly_inputs(forecast)[:hours]
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

    safe_windows: list[SafeWindow] = []
    current_start: str | None = None
    previous_hour: str | None = None
    for item in hourly:
        is_safe = item.level in ("low", "moderate")
        if is_safe and current_start is None:
            current_start = item.hour_iso
        if is_safe:
            previous_hour = item.hour_iso
        if not is_safe and current_start is not None and previous_hour is not None:
            safe_windows.append(SafeWindow(start_hour_iso=current_start, end_hour_iso=previous_hour))
            current_start = None
            previous_hour = None

    if current_start is not None and previous_hour is not None:
        safe_windows.append(SafeWindow(start_hour_iso=current_start, end_hour_iso=previous_hour))

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
