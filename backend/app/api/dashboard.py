from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.air import ProfileType, UserProfileContext
from app.models.dashboard import DashboardOverviewResponse
from app.models.risk import EnvironmentSnapshot, RiskEstimateResponse
import app.services.air_recommendation_engine as air_recommendation_engine
import app.services.air_risk_engine as air_risk_engine
import app.services.settings_repository as settings_repository
import app.services.notification_service as notification_service
import app.services.profile_access as profile_access
import app.services.recommendation_service as recommendation_service
import app.services.risk_repository as risk_repository
from app.services.air_repository import PERSONA_TO_PROFILE_TYPE
from app.services.air_score import RISK_LEVEL_TO_SCORE, to_air_environment
import app.services.air_environment_service as air_environment_service
import app.services.wearable_service as wearable_service
from app.services.forecast.mapping import (
    apply_freshness_source,
    forecast_point_to_environmental,
    forecast_to_hourly_inputs,
    retain_live_only_metrics,
)
from app.services.forecast.service import get_forecast

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


def _build_profile_context(profile_id: str | None, user_id: str, persona: str, lat: float, lon: float) -> UserProfileContext:
    mapped_profile = PERSONA_TO_PROFILE_TYPE.get(persona, ProfileType.ADULT_DEFAULT)
    return UserProfileContext(
        profile_id=profile_id or f"virtual-{user_id}",
        user_id=user_id,
        profile_type=mapped_profile,
        age_group=persona,
        home_lat=lat,
        home_lon=lon,
    )


def _forecast_bundle(lat: float, lon: float):
    try:
        return get_forecast(lat, lon)
    except Exception:
        return None


@router.get("/overview", response_model=DashboardOverviewResponse)
def dashboard_overview(
    profile_id: str | None = Query(default=None),
    persona: str = Query(default="adult"),
    lat: float = Query(default=41.39, ge=-90, le=90),
    lon: float = Query(default=2.17, ge=-180, le=180),
    user_id: str = Depends(get_current_user_id),
) -> DashboardOverviewResponse:
    if profile_id:
        try:
            if not profile_access.profile_exists(profile_id):
                raise HTTPException(status_code=404, detail="Profile not found")
            if not profile_access.profile_belongs_to_user(profile_id, user_id):
                raise HTTPException(status_code=403, detail="Profile does not belong to user")
            symptom_stats = risk_repository.get_recent_symptom_stats(profile_id=profile_id, hours=48)
        except PsycopgError as exc:
            raise HTTPException(status_code=503, detail="Database unavailable") from exc
    else:
        symptom_stats = {
            "cough_count": 0,
            "wheeze_count": 0,
            "headache_count": 0,
            "fatigue_count": 0,
            "total_logs": 0,
        }

    try:
        snapshot = air_environment_service.resolve_environment_snapshot(lat=lat, lon=lon)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail="Environmental data unavailable") from exc
    environment = EnvironmentSnapshot(
        temperature_c=snapshot.temperature_c,
        humidity_percent=snapshot.humidity_percent,
        aqi=snapshot.aqi,
        pm25=snapshot.pm25,
        ozone=snapshot.ozone,
        source=snapshot.source,
        pm10=snapshot.pm10,
        no2=snapshot.no2,
        uv=snapshot.uv,
        wind_speed=snapshot.wind_speed,
        feels_like=snapshot.feels_like,
        timezone=snapshot.timezone,
        pollen_grains_m3=snapshot.pollen_grains_m3,
        wildfire_pm10=snapshot.wildfire_pm10,
        wbgt_c=snapshot.wbgt_c,
        wbgt_estimated=snapshot.wbgt_estimated,
        shortwave_wm2=snapshot.shortwave_wm2,
    )
    forecast = _forecast_bundle(lat, lon)
    hourly_points = forecast_to_hourly_inputs(forecast) if forecast is not None else []
    if forecast is not None and forecast.current is not None:
        mapped = forecast_point_to_environmental(forecast.current)
        if mapped is not None:
            live_air = to_air_environment(environment, lat, lon)
            mapped = apply_freshness_source(
                retain_live_only_metrics(mapped, live_air),
                forecast.freshness.value,
            )
            environment = EnvironmentSnapshot(
                temperature_c=mapped.temperature,
                humidity_percent=mapped.humidity if mapped.humidity is not None else environment.humidity_percent,
                aqi=mapped.aqi,
                pm25=mapped.pm25,
                ozone=mapped.ozone,
                source=mapped.source,
                pm10=mapped.pm10,
                no2=mapped.no2,
                uv=mapped.uv,
                wind_speed=mapped.wind_speed,
                feels_like=mapped.feels_like,
                timezone=mapped.timezone or environment.timezone,
                pollen_grains_m3=mapped.pollen_grains_m3,
                wildfire_pm10=mapped.wildfire_pm10,
                # Forecast points do not carry WBGT — keep live meteo estimate.
                wbgt_c=environment.wbgt_c,
                wbgt_estimated=environment.wbgt_estimated,
                shortwave_wm2=environment.shortwave_wm2,
            )
    profile_context = _build_profile_context(profile_id, user_id, persona, lat, lon)
    air_environment = to_air_environment(environment, lat, lon)
    personal_load = wearable_service.build_personal_load_input(user_id, air_environment)
    air_risk = air_risk_engine.evaluate_risk(
        profile_context,
        air_environment,
        personal_load,
        hourly_points=hourly_points,
    )
    user_settings = settings_repository.get_user_settings(user_id)
    recommendation_card = air_recommendation_engine.generate_recommendation(
        profile_context,
        air_risk,
        language=user_settings.preferred_language,
    )
    risk_level = air_risk.overallRisk.value
    risk_score = RISK_LEVEL_TO_SCORE[risk_level]
    risk = RiskEstimateResponse(
        score=risk_score,
        level=risk_level,
        recommendations=recommendation_card.actions,
        components={
            "env_component": risk_score,
            "persona_component": 0,
            "symptom_component": 0,
        },
    )

    if (
        profile_id
        and environment.aqi is not None
        and environment.pm25 is not None
        and environment.ozone is not None
        and environment.humidity_percent is not None
    ):
        try:
            snapshot_id = risk_repository.save_environment_snapshot(environment)
            risk_repository.save_risk_score(
                profile_id=profile_id,
                risk=risk,
                snapshot_id=snapshot_id,
            )
        except PsycopgError as exc:
            raise HTTPException(status_code=503, detail="Database unavailable") from exc

    daily_summary, daily_actions = recommendation_service.build_daily_recommendation(
        risk_level=risk_level,
        symptom_stats=symptom_stats,
    )
    should_notify = notification_service.should_notify(risk)
    notification_text = notification_service.build_notification_text(risk)

    return DashboardOverviewResponse(
        profile_id=profile_id,
        environment=environment,
        risk_score=risk_score,
        risk_level=risk_level,
        recommendations=recommendation_card.actions,
        daily_summary=daily_summary,
        daily_actions=daily_actions,
        should_notify=should_notify,
        notification_text=notification_text,
    )
