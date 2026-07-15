from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id, get_optional_user_id
from app.models.product_analytics import (
    AnalyticsEventsBatchRequest,
    AnalyticsEventsBatchResponse,
    CrashReportRequest,
    CrashReportResponse,
    FeedbackSubmitRequest,
    FeedbackSubmitResponse,
    KpiDashboardResponse,
)
import app.services.product_analytics_repository as product_analytics_repository

router = APIRouter(tags=["product-analytics"])


@router.post("/analytics/events", response_model=AnalyticsEventsBatchResponse)
def ingest_analytics_events(
    payload: AnalyticsEventsBatchRequest,
    user_id: str | None = Depends(get_optional_user_id),
) -> AnalyticsEventsBatchResponse:
    try:
        created = product_analytics_repository.record_events(user_id=user_id, events=payload.events)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return AnalyticsEventsBatchResponse(accepted=len(created))


@router.get("/analytics/kpi-dashboard", response_model=KpiDashboardResponse)
def kpi_dashboard(
    days: int = Query(default=14, ge=1, le=90),
    user_id: str = Depends(get_current_user_id),
) -> KpiDashboardResponse:
    _ = user_id
    try:
        return product_analytics_repository.build_kpi_dashboard(window_days=days)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.post("/feedback", response_model=FeedbackSubmitResponse)
def submit_feedback(
    payload: FeedbackSubmitRequest,
    user_id: str | None = Depends(get_optional_user_id),
) -> FeedbackSubmitResponse:
    if not payload.liked.strip() and not payload.confusing.strip() and not payload.broken.strip():
        raise HTTPException(status_code=422, detail="At least one feedback field is required")
    try:
        return product_analytics_repository.submit_feedback(user_id=user_id, payload=payload)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.post("/crashes/report", response_model=CrashReportResponse)
def report_crash(
    payload: CrashReportRequest,
    user_id: str | None = Depends(get_optional_user_id),
) -> CrashReportResponse:
    try:
        return product_analytics_repository.submit_crash_report(user_id=user_id, payload=payload)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
