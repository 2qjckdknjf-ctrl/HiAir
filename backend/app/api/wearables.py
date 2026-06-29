from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.wearable import (
    WearableConsentRequest,
    WearableConsentResponse,
    WearableDailySummaryRequest,
    WearableDailySummaryResponse,
    WearableDataDeleteResponse,
    WearableHourlySummaryRequest,
    WearableSource,
    WearableTodayResponse,
)
import app.services.wearable_repository as wearable_repository
import app.services.wearable_service as wearable_service

router = APIRouter(prefix="/v1/wearables", tags=["wearables"])


@router.post("/consent", response_model=WearableConsentResponse)
def save_consent(
    payload: WearableConsentRequest,
    user_id: str = Depends(get_current_user_id),
) -> WearableConsentResponse:
    try:
        return wearable_repository.upsert_consent(user_id, payload)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.delete("/consent", response_model=WearableConsentResponse)
def revoke_consent(
    user_id: str = Depends(get_current_user_id),
    source: WearableSource | None = Query(default=None),
) -> WearableConsentResponse:
    try:
        revoked = wearable_repository.revoke_consent(user_id, source)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    if revoked is None:
        raise HTTPException(status_code=404, detail="No active consent found")
    return revoked


@router.post("/daily-summary", response_model=WearableDailySummaryResponse)
def upsert_daily_summary(
    payload: WearableDailySummaryRequest,
    user_id: str = Depends(get_current_user_id),
) -> WearableDailySummaryResponse:
    if not wearable_repository.has_active_consent(user_id, payload.source):
        raise HTTPException(status_code=403, detail="Active health data consent required")
    try:
        return wearable_repository.upsert_daily_summary(user_id, payload)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.post("/hourly-summary")
def upsert_hourly_summary(
    payload: WearableHourlySummaryRequest,
    user_id: str = Depends(get_current_user_id),
) -> dict:
    if not wearable_repository.has_active_consent(user_id, payload.source):
        raise HTTPException(status_code=403, detail="Active health data consent required")
    try:
        return wearable_repository.upsert_hourly_summary(user_id, payload)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.get("/today", response_model=WearableTodayResponse)
def get_today(
    user_id: str = Depends(get_current_user_id),
) -> WearableTodayResponse:
    try:
        return wearable_service.build_today_response(user_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.delete("/data", response_model=WearableDataDeleteResponse)
def delete_health_data(
    user_id: str = Depends(get_current_user_id),
) -> WearableDataDeleteResponse:
    try:
        daily_deleted, hourly_deleted = wearable_repository.delete_all_summaries(user_id)
        revoked = wearable_repository.revoke_consent(user_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return WearableDataDeleteResponse(
        deletedDaily=daily_deleted,
        deletedHourly=hourly_deleted,
        consentRevoked=revoked is not None,
    )
