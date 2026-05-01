from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.air import PersonalPatternInsight, PersonalPatternsResponse
import app.services.air_repository as air_repository
import app.services.correlation_engine as correlation_engine
import app.services.insights_repository as insights_repository

router = APIRouter(prefix="/insights", tags=["insights"])


@router.get("/personal-patterns", response_model=PersonalPatternsResponse)
def get_personal_patterns(
    profile_id: str = Query(..., alias="profile_id"),
    window_days: int = Query(default=30, ge=14, le=365),
    language: str = Query(default="ru"),
    user_id: str = Depends(get_current_user_id),
) -> PersonalPatternsResponse:
    try:
        profile = air_repository.get_profile_context(profile_id)
        if profile is None:
            raise HTTPException(status_code=404, detail="Profile not found")
        if profile.user_id != user_id:
            raise HTTPException(status_code=403, detail="Profile does not belong to user")

        samples = insights_repository.get_daily_correlation_samples(profile_id=profile_id, window_days=window_days)
        items = correlation_engine.compute_personal_patterns(samples=samples, language=language)
        insights_repository.replace_personal_correlations(profile_id=profile_id, window_days=window_days, items=items)

        # Response uses freshly computed text while the DB keeps numeric trace.
        response_items = [
            PersonalPatternInsight(
                factorA=item.factorA,
                factorB=item.factorB,
                coefficient=item.coefficient,
                pValue=item.pValue,
                sampleSize=item.sampleSize,
                humanReadableText=item.humanReadableText,
            )
            for item in items
        ]
        return PersonalPatternsResponse(
            profileId=profile_id,
            windowDays=window_days,
            generatedAt=correlation_engine.now_utc_iso(),
            items=response_items,
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
