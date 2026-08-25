from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError
from psycopg.errors import UndefinedTable

from app.api.deps import get_current_user_id
from app.models.air import CurrentRiskResponse, DayPlanResponse, RecommendationResponse, RecomputeRiskRequest
from app.models.hazard import HazardsResponse
import app.services.air_environment_service as air_environment_service
import app.services.air_repository as air_repository
import app.services.air_recommendation_engine as air_recommendation_engine
import app.services.ai_explanation_service as ai_explanation_service
import app.services.air_risk_engine as air_risk_engine
import app.services.hazard_engine as hazard_engine
import app.services.entitlement_service as entitlement_service
import app.services.health_analytics_service as health_analytics_service
import app.services.settings_repository as settings_repository
import app.services.wearable_repository as wearable_repository
import app.services.wearable_service as wearable_service
from app.services.forecast.mapping import (
    apply_freshness_source,
    forecast_point_to_environmental,
    forecast_to_hourly_inputs,
    overlay_forecast_current,
    retain_live_only_metrics,
)
from app.services.forecast.service import get_forecast
import app.services.travel_location as travel_location

router = APIRouter(prefix="/air", tags=["air"])


def _resolve_profile_for_user(profile_id: str, user_id: str):
    profile = air_repository.get_profile_context(profile_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.user_id != user_id:
        raise HTTPException(status_code=403, detail="Profile does not belong to user")
    return travel_location.apply_travel_location_override(user_id, profile)


def _health_context_for_ai(user_id: str, profile_id: str, language: str) -> list[str]:
    """Bounded wellness observations for AI. No raw biometric values."""
    try:
        consent = wearable_repository.get_active_consent(user_id)
    except UndefinedTable:
        return []
    if consent is None or not getattr(consent, "isActive", True):
        return []

    entitlement = entitlement_service.get_current_entitlement(user_id)
    if not entitlement.is_premium or not entitlement.advanced_insights_enabled:
        return []

    try:
        bundle = health_analytics_service.build_insights_bundle(
            user_id=user_id,
            profile_id=profile_id,
            window_days=30,
            language=language,
            require_active_consent=True,
        )
    except Exception:
        return []

    health_context: list[str] = []
    for card in (bundle.get("associations") or [])[:2]:
        title = getattr(card, "title", None) or (card.get("title") if isinstance(card, dict) else None)
        observation = getattr(card, "observation", None) or (
            card.get("observation") if isinstance(card, dict) else None
        )
        if title and observation:
            health_context.append(f"{title}: {observation}")
    for card in (bundle.get("trends") or [])[:1]:
        title = getattr(card, "title", None) or (card.get("title") if isinstance(card, dict) else None)
        observation = getattr(card, "observation", None) or (
            card.get("observation") if isinstance(card, dict) else None
        )
        if title and observation:
            health_context.append(f"{title}: {observation}")
    return health_context[:4]


def _load_forecast_or_none(lat: float, lon: float, force_refresh: bool = False):
    try:
        return get_forecast(lat, lon, force_refresh=force_refresh)
    except Exception:
        return None


def _compute_and_persist(profile_id: str, user_id: str, force_live: bool) -> CurrentRiskResponse:
    profile = _resolve_profile_for_user(profile_id, user_id)
    user_settings = settings_repository.get_user_settings(user_id)
    language = user_settings.preferred_language
    try:
        environment = air_environment_service.load_environment(
            profile,
            force_refresh=force_live,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail="Environmental data unavailable") from exc
    forecast = _load_forecast_or_none(profile.home_lat, profile.home_lon, force_refresh=force_live)
    hourly_points = []
    freshness = None
    data_quality = None
    sources = None
    generated_at = None
    if forecast is not None:
        if forecast.current is not None:
            mapped = forecast_point_to_environmental(forecast.current)
            if mapped is not None:
                environment = apply_freshness_source(
                    retain_live_only_metrics(mapped, environment),
                    forecast.freshness.value,
                )
        hourly_points = forecast_to_hourly_inputs(forecast)
        freshness = forecast.freshness.value
        data_quality = forecast.quality.value
        sources = forecast.sources
        generated_at = forecast.generated_at
    personal_load = wearable_service.build_personal_load_input(user_id, environment)
    risk = air_risk_engine.evaluate_risk(profile, environment, personal_load, hourly_points=hourly_points)
    recommendation = air_recommendation_engine.generate_recommendation(profile, risk, language=language)
    snapshot_id = None
    if (
        environment.aqi is not None
        and environment.pm25 is not None
        and environment.ozone is not None
        and environment.humidity is not None
    ):
        snapshot_id = air_repository.save_environment_snapshot(environment)
        assessment_id = air_repository.save_risk_assessment(profile.profile_id, snapshot_id, risk)
    else:
        assessment_id = None
    # Skip premium health-analytics prefetch on the dashboard critical path —
    # LLM still receives risk + recommendation facts; Insights/morning report
    # keep the richer health context.
    explanation, explanation_source = ai_explanation_service.generate_explanation(
        profile,
        risk,
        recommendation,
        language=language,
        risk_assessment_id=assessment_id,
        health_context=None,
    )
    if assessment_id is not None:
        air_repository.save_recommendation(
            risk_assessment_id=assessment_id,
            recommendation=recommendation,
            model_version=explanation_source,
        )

    return CurrentRiskResponse(
        profileId=profile.profile_id,
        assessedAt=environment.timestamp,
        environmental=environment,
        risk=risk,
        recommendation=recommendation,
        explanation=explanation,
        explanationSource=explanation_source,
        dataQuality=data_quality,
        freshness=freshness,
        sources=sources,
        generatedAt=generated_at,
    )


@router.get("/hazards", response_model=HazardsResponse)
def get_hazards(
    profileId: str = Query(...),
    user_id: str = Depends(get_current_user_id),
) -> HazardsResponse:
    try:
        profile = _resolve_profile_for_user(profileId, user_id)
        environment = air_environment_service.load_environment(profile)
        forecast = _load_forecast_or_none(profile.home_lat, profile.home_lon)
        freshness = None
        data_quality = None
        sources = None
        generated_at = None
        if forecast is not None:
            if forecast.current is not None:
                mapped = forecast_point_to_environmental(forecast.current)
                if mapped is not None:
                    environment = apply_freshness_source(
                        retain_live_only_metrics(mapped, environment),
                        forecast.freshness.value,
                    )
            freshness = forecast.freshness.value
            data_quality = forecast.quality.value
            sources = forecast.sources
            generated_at = forecast.generated_at
        assessment = hazard_engine.assess_multi_hazard(profile, environment)
        return HazardsResponse(
            profileId=profile.profile_id,
            assessedAt=environment.timestamp,
            environmental=environment,
            assessment=assessment,
            dataQuality=data_quality,
            freshness=freshness,
            sources=sources,
            generatedAt=generated_at,
        )
    except HTTPException:
        raise
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail="Environmental data unavailable") from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.get("/current-risk", response_model=CurrentRiskResponse)
def get_current_risk(
    profileId: str = Query(...),
    user_id: str = Depends(get_current_user_id),
) -> CurrentRiskResponse:
    try:
        return _compute_and_persist(profileId, user_id, force_live=False)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.get("/day-plan", response_model=DayPlanResponse)
def get_day_plan(
    profileId: str = Query(...),
    user_id: str = Depends(get_current_user_id),
) -> DayPlanResponse:
    try:
        entitlement_service.require_feature(user_id, "extended_forecast", "extended_forecast_enabled")
        profile = _resolve_profile_for_user(profileId, user_id)
        environment = air_environment_service.load_environment(profile)
        forecast = _load_forecast_or_none(profile.home_lat, profile.home_lon)
        environment = overlay_forecast_current(environment, forecast)
        hourly_points = forecast_to_hourly_inputs(forecast) if forecast is not None else []
        personal_load = wearable_service.build_personal_load_input(user_id, environment)
        return air_risk_engine.build_day_plan(
            profile,
            environment,
            hourly_points=hourly_points,
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


@router.get("/recommendations", response_model=RecommendationResponse)
def get_recommendations(
    profileId: str = Query(...),
    user_id: str = Depends(get_current_user_id),
) -> RecommendationResponse:
    try:
        profile = _resolve_profile_for_user(profileId, user_id)
        user_settings = settings_repository.get_user_settings(user_id)
        environment = air_environment_service.load_environment(profile)
        forecast = _load_forecast_or_none(profile.home_lat, profile.home_lon)
        hourly_points = forecast_to_hourly_inputs(forecast) if forecast is not None else []
        if forecast is not None and forecast.current is not None:
            mapped = forecast_point_to_environmental(forecast.current)
            if mapped is not None:
                environment = apply_freshness_source(
                    retain_live_only_metrics(mapped, environment),
                    forecast.freshness.value,
                )
        personal_load = wearable_service.build_personal_load_input(user_id, environment)
        risk = air_risk_engine.evaluate_risk(
            profile,
            environment,
            personal_load,
            hourly_points=hourly_points,
        )
        recommendation = air_recommendation_engine.generate_recommendation(
            profile,
            risk,
            language=user_settings.preferred_language,
        )
        return RecommendationResponse(
            profileId=profile.profile_id,
            recommendation=recommendation,
            risk=risk,
            generatedAt=environment.timestamp,
        )
    except HTTPException:
        raise
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail="Environmental data unavailable") from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.post("/recompute-risk", response_model=CurrentRiskResponse)
def recompute_risk(
    payload: RecomputeRiskRequest,
    user_id: str = Depends(get_current_user_id),
) -> CurrentRiskResponse:
    try:
        return _compute_and_persist(payload.profileId, user_id, force_live=payload.forceRefresh)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
