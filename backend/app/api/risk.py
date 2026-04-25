from fastapi import APIRouter, Depends, HTTPException, Query, Response
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.core.settings import settings
from app.models.risk import RiskEstimateRequest, RiskEstimateResponse, RiskHistoryItem
import app.services.profile_access as profile_access
from app.services.risk_level_contract import normalize_legacy_level_with_meta
import app.services.risk_repository as risk_repository
from app.services.risk_engine import estimate_risk

router = APIRouter(prefix="/risk", tags=["risk"])


def _apply_alias_warning_headers(response: Response) -> None:
    response.headers["X-HiAir-Risk-Alias-Policy"] = settings.risk_level_alias_mode
    response.headers["X-HiAir-Risk-Alias-Map"] = "moderate->medium"
    response.headers["X-HiAir-Risk-Alias-Sunset"] = settings.risk_level_alias_sunset_date


@router.post("/estimate", response_model=RiskEstimateResponse)
def risk_estimate(
    payload: RiskEstimateRequest,
    response: Response,
    user_id: str = Depends(get_current_user_id),
) -> RiskEstimateResponse:
    score, level, recommendations, components = estimate_risk(
        persona=payload.persona,
        symptoms=payload.symptoms,
        environment=payload.environment,
    )
    try:
        normalized_level, alias_used = normalize_legacy_level_with_meta(level)
    except ValueError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    result = RiskEstimateResponse(
        score=score,
        level=normalized_level,
        recommendations=recommendations,
        components=components,
    )
    if alias_used and response is not None and settings.risk_level_alias_mode == "warn":
        _apply_alias_warning_headers(response)
    if payload.profile_id:
        try:
            if not profile_access.profile_exists(payload.profile_id):
                raise HTTPException(status_code=404, detail="Profile not found")
            if not profile_access.profile_belongs_to_user(payload.profile_id, user_id):
                raise HTTPException(status_code=403, detail="Profile does not belong to user")
            snapshot_id = risk_repository.save_environment_snapshot(payload.environment)
            risk_repository.save_risk_score(
                profile_id=payload.profile_id,
                risk=result,
                snapshot_id=snapshot_id,
            )
        except PsycopgError as exc:
            raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return result


@router.get("/history", response_model=list[RiskHistoryItem])
def risk_history(
    response: Response,
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
    alias_used = False
    for row in rows:
        row_data = dict(row)
        try:
            normalized_level, item_alias_used = normalize_legacy_level_with_meta(
                str(row_data["risk_level"])
            )
        except ValueError as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        alias_used = alias_used or item_alias_used
        row_data["risk_level"] = normalized_level
        items.append(RiskHistoryItem(**row_data))
    if alias_used and response is not None and settings.risk_level_alias_mode == "warn":
        _apply_alias_warning_headers(response)
    return items
