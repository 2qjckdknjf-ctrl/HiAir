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

    snapshot = air_environment_service.resolve_environment_snapshot(lat=lat, lon=lon)
    environment = EnvironmentSnapshot(
        temperature_c=snapshot.temperature_c,
        humidity_percent=snapshot.humidity_percent,
        aqi=snapshot.aqi,
        pm25=snapshot.pm25,
        ozone=snapshot.ozone,
        source=snapshot.source,
    )
    profile_context = _build_profile_context(profile_id, user_id, persona, lat, lon)
    air_environment = to_air_environment(environment, lat, lon)
    air_risk = air_risk_engine.evaluate_risk(profile_context, air_environment)
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

    if profile_id:
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
