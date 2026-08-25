from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
import app.api.air as air_api
import app.services.entitlement_service as entitlement_service

from app.models.activity_plan import (
    ActivityCatalogResponse,
    ActivityPlanRequest,
    ActivityPlanResponse,
)
from app.models.air import SafeWindowType, UserProfileContext
from app.models.planner import DailyPlannerResponse, HourlyRiskItem, SafeWindow
from app.services.air_repository import PERSONA_TO_PROFILE_TYPE
from app.services.air_score import RISK_LEVEL_TO_SCORE
import app.services.activity_plan_engine as activity_plan_engine
import app.services.air_environment_service as air_environment_service
import app.services.air_risk_engine as air_risk_engine
import app.services.places_repository as places_repository
import app.services.wearable_service as wearable_service
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


@router.get("/activities", response_model=ActivityCatalogResponse)
def list_activities(
    user_id: str = Depends(get_current_user_id),
) -> ActivityCatalogResponse:
    _ = user_id
    return ActivityCatalogResponse(activities=activity_plan_engine.catalog())


@router.post("/activity-plan", response_model=ActivityPlanResponse)
def create_activity_plan(
    payload: ActivityPlanRequest,
    user_id: str = Depends(get_current_user_id),
) -> ActivityPlanResponse:
    try:
        entitlement_service.require_feature(
            user_id, "extended_forecast", "extended_forecast_enabled"
        )
        profile = air_api._resolve_profile_for_user(payload.profileId, user_id)
        lat = profile.home_lat
        lon = profile.home_lon
        if payload.placeId:
            place = places_repository.get_place(user_id=user_id, place_id=payload.placeId)
            if place is None:
                raise HTTPException(status_code=404, detail="Saved place not found")
            lat = place.lat
            lon = place.lon
        environment = air_environment_service.load_environment(profile)
        forecast = air_api._load_forecast_or_none(lat, lon)
        hourly_points = forecast_to_hourly_inputs(forecast) if forecast is not None else []
        personal_load = wearable_service.build_personal_load_input(user_id, environment)
        return activity_plan_engine.build_activity_plan(
            profile=profile,
            environment=environment,
            hourly_points=hourly_points,
            activity=payload.activity,
            duration_minutes=payload.durationMinutes,
            intensity=payload.intensity,
            earliest_start=payload.earliestStart,
            latest_start=payload.latestStart,
            personal_load=personal_load,
            generated_at=forecast.generated_at if forecast is not None else None,
            freshness=forecast.freshness.value if forecast is not None else None,
            data_quality=forecast.quality.value if forecast is not None else "unavailable",
            sources=forecast.sources if forecast is not None else None,
            missing_metrics=forecast.missing_metrics if forecast is not None else None,
        )
    except HTTPException:
        raise
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail="Environmental data unavailable") from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
