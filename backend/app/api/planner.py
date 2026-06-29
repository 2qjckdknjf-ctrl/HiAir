from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from app.api.deps import get_current_user_id
import app.services.entitlement_service as entitlement_service

from app.models.air import UserProfileContext
from app.models.planner import DailyPlannerResponse, HourlyRiskItem, SafeWindow
from app.models.risk import EnvironmentSnapshot
import app.services.air_risk_engine as air_risk_engine
from app.services.air_repository import PERSONA_TO_PROFILE_TYPE
from app.services.air_score import RISK_LEVEL_TO_SCORE, to_air_environment
import app.services.air_environment_service as air_environment_service

router = APIRouter(prefix="/planner", tags=["planner"])


def _normalize_persona(value: str) -> str:
    normalized = value.lower()
    return normalized if normalized in PERSONA_TO_PROFILE_TYPE else "adult"


def _shift_env(base: EnvironmentSnapshot, hour_offset: int) -> EnvironmentSnapshot:
    # Simple deterministic curve: noon hotter, evening cooler.
    daytime_factor = max(0, 6 - abs(12 - ((datetime.now(timezone.utc).hour + hour_offset) % 24)))
    temp = base.temperature_c + (daytime_factor * 0.8) - 2.0
    humidity = max(20.0, min(95.0, base.humidity_percent - (daytime_factor * 1.2) + 3.0))
    aqi = max(5, int(base.aqi + (daytime_factor * 2) - 3))
    pm25 = max(1.0, base.pm25 + (daytime_factor * 0.7) - 1.0)
    ozone = max(1.0, base.ozone + (daytime_factor * 1.1) - 1.5)
    return EnvironmentSnapshot(
        temperature_c=float(round(temp, 1)),
        humidity_percent=float(round(humidity, 1)),
        aqi=aqi,
        pm25=float(round(pm25, 1)),
        ozone=float(round(ozone, 1)),
        source=base.source,
    )


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
    base_env = air_environment_service.resolve_environment_snapshot(lat=lat, lon=lon)

    now = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0)
    hourly: list[HourlyRiskItem] = []
    for hour_offset in range(hours):
        slot_time = now + timedelta(hours=hour_offset)
        slot_env = _shift_env(base_env, hour_offset)
        slot_iso = slot_time.isoformat()
        air_environment = to_air_environment(slot_env, lat, lon, timestamp=slot_iso)
        risk = air_risk_engine.evaluate_risk(profile_context, air_environment)
        level = risk.overallRisk.value
        score = RISK_LEVEL_TO_SCORE[level]
        hourly.append(
            HourlyRiskItem(
                hour_iso=slot_iso,
                score=score,
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
    )
