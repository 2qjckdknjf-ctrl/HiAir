from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.recommendation import DailyRecommendationResponse
import app.services.profile_access as profile_access
import app.services.recommendation_service as recommendation_service
import app.services.risk_repository as risk_repository
import app.services.settings_repository as settings_repository
from app.services.localization import normalize_language

router = APIRouter(prefix="/recommendations", tags=["recommendations"])


@router.get("/daily", response_model=DailyRecommendationResponse)
def daily_recommendation(
    profile_id: str = Query(...),
    language: Annotated[str | None, Query()] = None,
    accept_language: Annotated[str | None, Header(alias="Accept-Language")] = None,
    user_id: str = Depends(get_current_user_id),
) -> DailyRecommendationResponse:
    try:
        if not profile_access.profile_exists(profile_id):
            raise HTTPException(status_code=404, detail="Profile not found")
        if not profile_access.profile_belongs_to_user(profile_id, user_id):
            raise HTTPException(status_code=403, detail="Profile does not belong to user")
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc

    try:
        history = risk_repository.get_risk_history(profile_id=profile_id, limit=1)
        symptom_stats = risk_repository.get_recent_symptom_stats(profile_id=profile_id, hours=48)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc

    latest_level = history[0]["risk_level"] if history else "low"
    preferred_language = language or accept_language
    if preferred_language is None:
        try:
            preferred_language = settings_repository.get_user_settings(user_id).preferred_language
        except PsycopgError as exc:
            raise HTTPException(status_code=503, detail="Database unavailable") from exc
    summary, actions = recommendation_service.build_daily_recommendation(
        risk_level=latest_level,
        symptom_stats=symptom_stats,
        language=normalize_language(preferred_language),
    )
    return DailyRecommendationResponse(
        profile_id=profile_id,
        risk_level=latest_level,
        summary=summary,
        actions=actions,
    )
