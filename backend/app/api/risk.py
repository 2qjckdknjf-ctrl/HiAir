from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.risk import RiskEstimateRequest, RiskEstimateResponse, RiskHistoryItem
import app.services.profile_access as profile_access
from app.services.risk_level_contract import normalize_legacy_level
import app.services.risk_repository as risk_repository
from app.services.risk_engine import estimate_risk

router = APIRouter(prefix="/risk", tags=["risk"])


@router.post("/estimate", response_model=RiskEstimateResponse)
def risk_estimate(
    payload: RiskEstimateRequest,
    user_id: str = Depends(get_current_user_id),
) -> RiskEstimateResponse:
    score, level, recommendations, components = estimate_risk(
        persona=payload.persona,
        symptoms=payload.symptoms,
        environment=payload.environment,
    )
    response = RiskEstimateResponse(
        score=score,
        level=normalize_legacy_level(level),
        recommendations=recommendations,
        components=components,
    )
    if payload.profile_id:
        try:
            if not profile_access.profile_exists(payload.profile_id):
                raise HTTPException(status_code=404, detail="Profile not found")
            if not profile_access.profile_belongs_to_user(payload.profile_id, user_id):
                raise HTTPException(status_code=403, detail="Profile does not belong to user")
            snapshot_id = risk_repository.save_environment_snapshot(payload.environment)
            risk_repository.save_risk_score(
                profile_id=payload.profile_id,
                risk=response,
                snapshot_id=snapshot_id,
            )
        except PsycopgError as exc:
            raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return response


@router.get("/history", response_model=list[RiskHistoryItem])
def risk_history(
    profile_id: str = Query(...),
    limit: int = Query(default=20, ge=1, le=100),
    user_id: str = Depends(get_current_user_id),
) -> list[RiskHistoryItem]:
    try:
        if not profile_access.profile_exists(profile_id):
            raise HTTPException(status_code=404, detail="Profile not found")
        if not profile_access.profile_belongs_to_user(profile_id, user_id):
            raise HTTPException(status_code=403, detail="Profile does not belong to user")
        rows = risk_repository.get_risk_history(profile_id=profile_id, limit=limit)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    items: list[RiskHistoryItem] = []
    for row in rows:
        row_data = dict(row)
        row_data["risk_level"] = normalize_legacy_level(str(row_data["risk_level"]))
        items.append(RiskHistoryItem(**row_data))
    return items
