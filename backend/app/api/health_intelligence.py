from datetime import date

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
import app.services.entitlement_service as entitlement_service
from app.models.health_intelligence import (
    ComprehensiveSymptomCreateRequest,
    ComprehensiveSymptomResponse,
    CustomSymptomCreateRequest,
    CustomSymptomResponse,
    HealthAvailabilityItem,
    HealthAvailabilityResponse,
    HealthDataDeleteResponse,
    HealthInsightsBundleResponse,
    HealthSummaryMetric,
    HealthSummaryResponse,
    HealthSyncRequest,
    HealthSyncResponse,
    HealthTimelinePoint,
    HealthTimelineResponse,
    InsightCard,
    QualityState,
    SleepSummaryItem,
)
from app.models.wearable import WearablePlatform, WearableSource
import app.services.health_analytics_service as health_analytics_service
import app.services.health_sync_repository as health_sync_repository
import app.services.profile_access as profile_access
import app.services.symptom_entry_repository as symptom_entry_repository
import app.services.wearable_repository as wearable_repository
from app.services.health_metrics import CANONICAL_METRICS, consent_allows_metric
from app.services.symptom_taxonomy import taxonomy_payload

router = APIRouter(prefix="/v1/health", tags=["health-intelligence"])


@router.post("/sync", response_model=HealthSyncResponse)
def sync_health(
    payload: HealthSyncRequest,
    user_id: str = Depends(get_current_user_id),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
) -> HealthSyncResponse:
    if payload.profileId:
        if not profile_access.profile_exists(payload.profileId):
            raise HTTPException(status_code=404, detail="Profile not found")
        if not profile_access.profile_belongs_to_user(payload.profileId, user_id):
            raise HTTPException(status_code=403, detail="Profile does not belong to user")
    consent = wearable_repository.get_active_consent(user_id, payload.source)
    if consent is None or not consent.isActive:
        raise HTTPException(status_code=403, detail="Active health data consent required")
    # Idempotency key is accepted for clients; upserts are naturally idempotent by unique keys.
    _ = idempotency_key or payload.idempotencyKey
    try:
        accepted, rejected, sleep_ok, last_success = health_sync_repository.apply_sync(
            user_id, payload, consent=consent
        )
        mirror_payload = payload.model_copy(
            update={
                "metrics": [
                    m
                    for m in payload.metrics
                    if consent_allows_metric(consent, m.metricType)
                ],
                "sleep": payload.sleep if sleep_ok else None,
            }
        )
        health_sync_repository.mirror_legacy_daily_from_metrics(user_id, mirror_payload)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    status = "success" if not rejected else ("partial" if accepted or sleep_ok else "error")
    return HealthSyncResponse(
        acceptedMetrics=accepted,
        rejectedMetrics=rejected,
        sleepAccepted=sleep_ok,
        syncStatus=status,
        lastSuccessAt=last_success,
    )


@router.get("/summary", response_model=HealthSummaryResponse)
def get_summary(
    local_date: date | None = Query(default=None),
    user_id: str = Depends(get_current_user_id),
) -> HealthSummaryResponse:
    day = local_date or date.today()
    try:
        rows = health_sync_repository.list_metrics_for_date(user_id, day)
        sleep_row = health_sync_repository.get_sleep_for_date(user_id, day)
        metric_days = health_sync_repository.count_metric_days(user_id, "steps", days=30)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc

    metrics: list[HealthSummaryMetric] = []
    for row in rows:
        metric_type = str(row["metric_type"])
        baseline = health_sync_repository.metric_baseline(user_id, metric_type, days=30)
        current = None
        for key in ("value_avg", "value_total", "value_latest"):
            if row.get(key) is not None:
                current = float(row[key])
                break
        deviation = None
        if baseline is not None and current is not None:
            deviation = current - baseline
        metrics.append(
            HealthSummaryMetric(
                metricType=metric_type,
                unit=str(row["unit"]),
                valueAvg=_f(row.get("value_avg")),
                valueMin=_f(row.get("value_min")),
                valueMax=_f(row.get("value_max")),
                valueLatest=_f(row.get("value_latest")),
                valueTotal=_f(row.get("value_total")),
                sampleCount=int(row.get("sample_count") or 0),
                qualityState=str(row.get("quality_state") or "ok"),
                hrvMethod=row.get("hrv_method"),
                trend7d=None,
                baseline30d=baseline,
                deviationFromBaseline=deviation,
            )
        )
    sleep = None
    if sleep_row:
        sleep = SleepSummaryItem(
            localDate=sleep_row["local_date"],
            totalMinutes=sleep_row.get("total_minutes"),
            inBedMinutes=sleep_row.get("in_bed_minutes"),
            awakeMinutes=sleep_row.get("awake_minutes"),
            coreLightMinutes=sleep_row.get("core_light_minutes"),
            deepMinutes=sleep_row.get("deep_minutes"),
            remMinutes=sleep_row.get("rem_minutes"),
            sleepStart=sleep_row.get("sleep_start"),
            sleepEnd=sleep_row.get("sleep_end"),
            qualityState=QualityState(sleep_row.get("quality_state") or "ok"),
        )
    return HealthSummaryResponse(
        localDate=day,
        timezone=sleep_row.get("timezone") if sleep_row else "UTC",
        metrics=metrics,
        sleep=sleep,
        dataDaysAvailable=metric_days,
    )


@router.get("/timeline", response_model=HealthTimelineResponse)
def get_timeline(
    profile_id: str = Query(..., alias="profile_id"),
    window_days: int = Query(default=30, ge=7, le=90),
    user_id: str = Depends(get_current_user_id),
) -> HealthTimelineResponse:
    if not profile_access.profile_exists(profile_id):
        raise HTTPException(status_code=404, detail="Profile not found")
    if not profile_access.profile_belongs_to_user(profile_id, user_id):
        raise HTTPException(status_code=403, detail="Profile does not belong to user")
    try:
        points = health_analytics_service.build_timeline(
            user_id=user_id,
            profile_id=profile_id,
            window_days=window_days,
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return HealthTimelineResponse(
        profileId=profile_id,
        windowDays=window_days,
        points=[HealthTimelinePoint(**point) for point in points],
    )


@router.get("/availability", response_model=HealthAvailabilityResponse)
def get_availability(
    user_id: str = Depends(get_current_user_id),
) -> HealthAvailabilityResponse:
    try:
        sync = health_sync_repository.get_sync_state(user_id)
        today_rows = health_sync_repository.list_metrics_for_date(user_id, date.today())
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    by_type = {row["metric_type"]: row for row in today_rows}
    items = []
    for metric_type, meta in CANONICAL_METRICS.items():
        row = by_type.get(metric_type)
        if row:
            latest = None
            for key in ("value_latest", "value_avg", "value_total"):
                if row.get(key) is not None:
                    latest = float(row[key])
                    break
            items.append(
                HealthAvailabilityItem(
                    metricType=metric_type,
                    category=meta["category"],
                    qualityState=QualityState(row.get("quality_state") or "ok"),
                    lastSyncedAt=row.get("synced_at"),
                    unit=str(row.get("unit")),
                    latestValue=latest,
                )
            )
        else:
            items.append(
                HealthAvailabilityItem(
                    metricType=metric_type,
                    category=meta["category"],
                    qualityState=QualityState.NO_RECORDS,
                    lastSyncedAt=None,
                    unit=meta["unit"],
                    latestValue=None,
                )
            )
    platform = None
    source = None
    if sync:
        try:
            platform = WearablePlatform(sync["platform"])
            source = WearableSource(sync["source_platform"])
        except Exception:
            platform = None
            source = None
    return HealthAvailabilityResponse(
        platform=platform,
        source=source,
        lastSuccessAt=sync.get("last_success_at") if sync else None,
        syncStatus=sync.get("sync_status") if sync else None,
        items=items,
    )


@router.delete("/data", response_model=HealthDataDeleteResponse)
def delete_health_data(
    user_id: str = Depends(get_current_user_id),
) -> HealthDataDeleteResponse:
    try:
        metrics, sleep, daily, hourly = health_sync_repository.delete_all_health_data(user_id)
        revoked = wearable_repository.revoke_consent(user_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return HealthDataDeleteResponse(
        deletedMetrics=metrics,
        deletedSleep=sleep,
        deletedLegacyDaily=daily,
        deletedLegacyHourly=hourly,
        consentRevoked=revoked is not None,
    )


@router.get("/insights", response_model=HealthInsightsBundleResponse)
def get_health_insights(
    profile_id: str = Query(..., alias="profile_id"),
    window_days: int = Query(default=30, ge=7, le=90),
    language: str = Query(default="ru"),
    user_id: str = Depends(get_current_user_id),
) -> HealthInsightsBundleResponse:
    # Analytics bundle is Premium (advanced_insights); raw sync/summary stay free.
    entitlement_service.require_feature(user_id, "advanced_insights", "advanced_insights_enabled")
    if not profile_access.profile_exists(profile_id):
        raise HTTPException(status_code=404, detail="Profile not found")
    if not profile_access.profile_belongs_to_user(profile_id, user_id):
        raise HTTPException(status_code=403, detail="Profile does not belong to user")
    try:
        bundle = health_analytics_service.build_insights_bundle(
            user_id=user_id,
            profile_id=profile_id,
            window_days=window_days,
            language=language,
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return HealthInsightsBundleResponse(
        profileId=bundle["profileId"],
        generatedAt=bundle["generatedAt"],
        today=bundle["today"],
        trends=[InsightCard(**c.model_dump()) if isinstance(c, InsightCard) else InsightCard(**c) for c in bundle["trends"]],
        associations=[
            InsightCard(**c.model_dump()) if isinstance(c, InsightCard) else InsightCard(**c)
            for c in bundle["associations"]
        ],
        insufficientData=bundle["insufficientData"],
        healthDataStatus=bundle["healthDataStatus"],
    )


@router.get("/symptoms/taxonomy")
def get_symptom_taxonomy(language: str = Query(default="ru")) -> dict:
    return taxonomy_payload(language)


@router.post("/symptoms", response_model=ComprehensiveSymptomResponse)
def create_symptom(
    payload: ComprehensiveSymptomCreateRequest,
    language: str = Query(default="ru"),
    user_id: str = Depends(get_current_user_id),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
) -> ComprehensiveSymptomResponse:
    if not profile_access.profile_exists(payload.profileId):
        raise HTTPException(status_code=404, detail="Profile not found")
    if not profile_access.profile_belongs_to_user(payload.profileId, user_id):
        raise HTTPException(status_code=403, detail="Profile does not belong to user")
    if idempotency_key and not payload.clientRequestId:
        payload = payload.model_copy(update={"clientRequestId": idempotency_key.strip()[:64]})
    try:
        return symptom_entry_repository.create_comprehensive_entry(user_id, payload, language=language)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.patch("/symptoms/{entry_id}")
def patch_symptom(
    entry_id: str,
    profile_id: str = Query(..., alias="profile_id"),
    severity: int | None = Query(default=None, ge=1, le=5),
    note: str | None = Query(default=None),
    duration_minutes: int | None = Query(default=None, ge=0, le=10080),
    ongoing: bool | None = Query(default=None),
    user_id: str = Depends(get_current_user_id),
) -> dict:
    if not profile_access.profile_belongs_to_user(profile_id, user_id):
        raise HTTPException(status_code=403, detail="Profile does not belong to user")
    try:
        updated = symptom_entry_repository.update_entry(
            user_id,
            profile_id,
            entry_id,
            severity=severity,
            note=note,
            duration_minutes=duration_minutes,
            ongoing=ongoing,
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    if updated is None:
        raise HTTPException(status_code=404, detail="Symptom entry not found")
    return {"id": str(updated["id"]), "updated": True}


@router.delete("/symptoms/{entry_id}")
def delete_symptom(
    entry_id: str,
    profile_id: str = Query(..., alias="profile_id"),
    user_id: str = Depends(get_current_user_id),
) -> dict:
    if not profile_access.profile_belongs_to_user(profile_id, user_id):
        raise HTTPException(status_code=403, detail="Profile does not belong to user")
    try:
        ok = symptom_entry_repository.soft_delete_entry(user_id, profile_id, entry_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    if not ok:
        raise HTTPException(status_code=404, detail="Symptom entry not found")
    return {"id": entry_id, "deleted": True}


@router.post("/symptoms/custom", response_model=CustomSymptomResponse)
def create_custom(
    payload: CustomSymptomCreateRequest,
    user_id: str = Depends(get_current_user_id),
) -> CustomSymptomResponse:
    if not profile_access.profile_belongs_to_user(payload.profileId, user_id):
        raise HTTPException(status_code=403, detail="Profile does not belong to user")
    try:
        return symptom_entry_repository.create_custom_symptom(user_id, payload)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.get("/symptoms/custom", response_model=list[CustomSymptomResponse])
def list_custom(
    profile_id: str = Query(..., alias="profile_id"),
    user_id: str = Depends(get_current_user_id),
) -> list[CustomSymptomResponse]:
    if not profile_access.profile_belongs_to_user(profile_id, user_id):
        raise HTTPException(status_code=403, detail="Profile does not belong to user")
    try:
        return symptom_entry_repository.list_custom_symptoms(user_id, profile_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.post("/symptoms/favorites")
def set_favorite(
    profile_id: str = Query(..., alias="profile_id"),
    symptom_type: str = Query(..., alias="symptom_type"),
    enabled: bool = Query(default=True),
    user_id: str = Depends(get_current_user_id),
) -> dict:
    if not profile_access.profile_belongs_to_user(profile_id, user_id):
        raise HTTPException(status_code=403, detail="Profile does not belong to user")
    try:
        symptom_entry_repository.set_favorite(user_id, profile_id, symptom_type, enabled)
        favorites = symptom_entry_repository.list_favorites(user_id, profile_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return {"favorites": favorites}


@router.get("/symptoms/favorites")
def get_favorites(
    profile_id: str = Query(..., alias="profile_id"),
    user_id: str = Depends(get_current_user_id),
) -> dict:
    if not profile_access.profile_belongs_to_user(profile_id, user_id):
        raise HTTPException(status_code=403, detail="Profile does not belong to user")
    try:
        favorites = symptom_entry_repository.list_favorites(user_id, profile_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return {"favorites": favorites}


def _f(value: object) -> float | None:
    if value is None:
        return None
    return float(value)
