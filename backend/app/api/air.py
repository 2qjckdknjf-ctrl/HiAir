from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.air import CurrentRiskResponse, DayPlanResponse, RecommendationResponse, RecomputeRiskRequest
import app.services.air_environment_service as air_environment_service
import app.services.air_repository as air_repository
import app.services.air_recommendation_engine as air_recommendation_engine
import app.services.ai_explanation_service as ai_explanation_service
import app.services.air_risk_engine as air_risk_engine
import app.services.settings_repository as settings_repository

router = APIRouter(prefix="/air", tags=["air"])


def _resolve_profile_for_user(profile_id: str, user_id: str):
    profile = air_repository.get_profile_context(profile_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.user_id != user_id:
        raise HTTPException(status_code=403, detail="Profile does not belong to user")
    return profile


def _compute_and_persist(profile_id: str, user_id: str, force_live: bool) -> CurrentRiskResponse:
    profile = _resolve_profile_for_user(profile_id, user_id)
    user_settings = settings_repository.get_user_settings(user_id)
    language = user_settings.preferred_language
    environment = air_environment_service.load_environment(profile, force_live=force_live)
    risk = air_risk_engine.evaluate_risk(profile, environment)
    recommendation = air_recommendation_engine.generate_recommendation(profile, risk, language=language)
    snapshot_id = air_repository.save_environment_snapshot(environment)
    assessment_id = air_repository.save_risk_assessment(profile.profile_id, snapshot_id, risk)
    explanation, explanation_source = ai_explanation_service.generate_explanation(
        profile,
        risk,
        recommendation,
        language=language,
        risk_assessment_id=assessment_id,
    )
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
    )


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
        profile = _resolve_profile_for_user(profileId, user_id)
        environment = air_environment_service.load_environment(profile, force_live=False)
        return air_risk_engine.build_day_plan(profile, environment)
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
        environment = air_environment_service.load_environment(profile, force_live=False)
        risk = air_risk_engine.evaluate_risk(profile, environment)
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
