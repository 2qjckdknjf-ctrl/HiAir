from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
import app.services.entitlement_service as entitlement_service
from app.models.air import PersonalPatternInsight, PersonalPatternsResponse
from app.models.personal_adaptation import (
    PersonalAdaptationSnapshot,
    ProtectedDayEventCreateRequest,
    ProtectedDayEventRecord,
)
import app.services.air_repository as air_repository
import app.services.correlation_engine as correlation_engine
import app.services.health_sync_repository as health_sync_repository
import app.services.insights_repository as insights_repository
import app.services.personal_adaptation_engine as personal_adaptation_engine
import app.services.protected_day_events_repository as protected_day_events_repository
import app.services.wearable_repository as wearable_repository

router = APIRouter(prefix="/insights", tags=["insights"])


@router.get("/personal-patterns", response_model=PersonalPatternsResponse)
def get_personal_patterns(
    profile_id: str = Query(..., alias="profile_id"),
    window_days: int = Query(default=30, ge=14, le=365),
    language: str = Query(default="ru"),
    user_id: str = Depends(get_current_user_id),
) -> PersonalPatternsResponse:
    try:
        entitlement_service.require_feature(user_id, "advanced_insights", "advanced_insights_enabled")
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


@router.get("/adaptation", response_model=PersonalAdaptationSnapshot)
def get_personal_adaptation(
    profile_id: str = Query(..., alias="profileId"),
    user_id: str = Depends(get_current_user_id),
) -> PersonalAdaptationSnapshot:
    try:
        entitlement_service.require_feature(user_id, "wearable_insights", "wearable_insights_enabled")
        profile = air_repository.get_profile_context(profile_id)
        if profile is None:
            raise HTTPException(status_code=404, detail="Profile not found")
        if profile.user_id != user_id:
            raise HTTPException(status_code=403, detail="Profile does not belong to user")

        consent = wearable_repository.get_active_consent(user_id)
        protected_events = protected_day_events_repository.list_events(
            profile_id=profile_id,
            user_id=user_id,
        )
        if consent is None or not consent.isActive:
            return personal_adaptation_engine.build_adaptation_snapshot(
                profile_id=profile_id,
                baseline_inputs=personal_adaptation_engine.BaselineInputs(),
                protected_events=protected_events,
                generated_at=personal_adaptation_engine.now_utc_iso(),
            )

        today = date.today()
        start = today - timedelta(days=29)
        metric_rows = health_sync_repository.list_metrics_window(
            user_id=user_id,
            start_date=start,
            end_date=today,
        )
        sleep_rows = health_sync_repository.get_sleep_window(
            user_id=user_id,
            start_date=start,
            end_date=today,
        )
        baseline_inputs = personal_adaptation_engine.build_baseline_inputs_from_metric_rows(
            metric_rows=metric_rows,
            sleep_rows=sleep_rows,
            reference_date=today,
        )
        return personal_adaptation_engine.build_adaptation_snapshot(
            profile_id=profile_id,
            baseline_inputs=baseline_inputs,
            protected_events=protected_events,
            generated_at=personal_adaptation_engine.now_utc_iso(),
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.post("/protected-day-events", response_model=ProtectedDayEventRecord)
def create_protected_day_event(
    payload: ProtectedDayEventCreateRequest,
    user_id: str = Depends(get_current_user_id),
) -> ProtectedDayEventRecord:
    try:
        entitlement_service.require_feature(user_id, "wearable_insights", "wearable_insights_enabled")
        profile = air_repository.get_profile_context(payload.profileId)
        if profile is None:
            raise HTTPException(status_code=404, detail="Profile not found")
        if profile.user_id != user_id:
            raise HTTPException(status_code=403, detail="Profile does not belong to user")

        try:
            event_type = personal_adaptation_engine.ProtectedDayEventType(payload.eventType)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail="Unsupported protected-day event type") from exc

        event_date: date | None = None
        if payload.eventDate:
            try:
                event_date = date.fromisoformat(payload.eventDate[:10])
            except ValueError as exc:
                raise HTTPException(status_code=422, detail="Invalid eventDate") from exc

        record = protected_day_events_repository.record_event(
            user_id=user_id,
            profile_id=payload.profileId,
            event_type=event_type,
            event_date=event_date,
        )
        resolved_date = record["event_date"]
        date_text = (
            resolved_date.isoformat()
            if hasattr(resolved_date, "isoformat")
            else str(resolved_date)
        )
        return ProtectedDayEventRecord(
            id=str(record["id"]),
            profileId=payload.profileId,
            eventType=event_type.value,
            eventDate=date_text,
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
