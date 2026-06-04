from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.recommendation import DailyRecommendationResponse
import app.services.profile_access as profile_access
import app.services.recommendation_service as recommendation_service
import app.services.risk_repository as risk_repository
import app.services.entitlement_service as entitlement_service

router = APIRouter(prefix="/recommendations", tags=["recommendations"])


@router.get("/daily", response_model=DailyRecommendationResponse)
def daily_recommendation(
    profile_id: str = Query(...),
    user_id: str = Depends(get_current_user_id),
) -> DailyRecommendationResponse:
    try:
        if not profile_access.profile_exists(profile_id):
            raise HTTPException(status_code=404, detail="Profile not found")
        if not profile_access.profile_belongs_to_user(profile_id, user_id):
            raise HTTPException(status_code=403, detail="Profile does not belong to user")
        entitlement_service.require_feature(
            user_id,
            "daily_recommendations",
            "advanced_insights_enabled",
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc

    try:
        history = risk_repository.get_risk_history(profile_id=profile_id, limit=1)
        symptom_stats = risk_repository.get_recent_symptom_stats(profile_id=profile_id, hours=48)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc

    latest_level = history[0]["risk_level"] if history else "low"
    summary, actions = recommendation_service.build_daily_recommendation(
        risk_level=latest_level,
        symptom_stats=symptom_stats,
    )
    return DailyRecommendationResponse(
        profile_id=profile_id,
        risk_level=latest_level,
        summary=summary,
        actions=actions,
    )
