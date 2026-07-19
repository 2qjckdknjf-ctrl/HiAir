from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any
from uuid import uuid4

from psycopg.types.json import Json

from app.models.health_intelligence import (
    HealthSyncRequest,
    MetricSummaryItem,
    SleepSummaryItem,
)
from app.services.db import get_connection
from app.services.health_metrics import (
    CANONICAL_METRICS,
    consent_allows_metric,
    consent_allows_sleep_summary,
)


def upsert_metric_daily(
    user_id: str,
    profile_id: str | None,
    local_date: date,
    timezone_name: str,
    source_platform: str,
    item: MetricSummaryItem,
) -> None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO wearable_metric_daily (
                    id, user_id, profile_id, local_date, timezone, metric_type,
                    value_avg, value_min, value_max, value_latest, value_total,
                    unit, sample_count, source_platform, source_device_class,
                    quality_state, hrv_method, period_start, period_end,
                    synced_at, created_at, updated_at
                )
                VALUES (
                    %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s,
                    %s, %s, %s, %s,
                    %s, %s, %s, %s,
                    NOW(), NOW(), NOW()
                )
                ON CONFLICT (user_id, local_date, metric_type, source_platform)
                DO UPDATE SET
                    profile_id = EXCLUDED.profile_id,
                    timezone = EXCLUDED.timezone,
                    value_avg = EXCLUDED.value_avg,
                    value_min = EXCLUDED.value_min,
                    value_max = EXCLUDED.value_max,
                    value_latest = EXCLUDED.value_latest,
                    value_total = EXCLUDED.value_total,
                    unit = EXCLUDED.unit,
                    sample_count = EXCLUDED.sample_count,
                    source_device_class = EXCLUDED.source_device_class,
                    quality_state = EXCLUDED.quality_state,
                    hrv_method = EXCLUDED.hrv_method,
                    period_start = EXCLUDED.period_start,
                    period_end = EXCLUDED.period_end,
                    synced_at = NOW(),
                    updated_at = NOW()
                """,
                (
                    str(uuid4()),
                    user_id,
                    profile_id,
                    local_date,
                    timezone_name,
                    item.metricType,
                    item.valueAvg,
                    item.valueMin,
                    item.valueMax,
                    item.valueLatest,
                    item.valueTotal,
                    item.unit,
                    item.sampleCount,
                    source_platform,
                    item.sourceDeviceClass,
                    item.qualityState.value,
                    item.hrvMethod,
                    item.periodStart,
                    item.periodEnd,
                ),
            )


def upsert_sleep_summary(
    user_id: str,
    profile_id: str | None,
    timezone_name: str,
    source_platform: str,
    sleep: SleepSummaryItem,
) -> None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO wearable_sleep_summaries (
                    id, user_id, profile_id, local_date, timezone,
                    total_minutes, in_bed_minutes, awake_minutes,
                    core_light_minutes, deep_minutes, rem_minutes,
                    sleep_start, sleep_end, source_platform, quality_state,
                    synced_at, created_at, updated_at
                )
                VALUES (
                    %s, %s, %s, %s, %s,
                    %s, %s, %s,
                    %s, %s, %s,
                    %s, %s, %s, %s,
                    NOW(), NOW(), NOW()
                )
                ON CONFLICT (user_id, local_date, source_platform)
                DO UPDATE SET
                    profile_id = EXCLUDED.profile_id,
                    timezone = EXCLUDED.timezone,
                    total_minutes = EXCLUDED.total_minutes,
                    in_bed_minutes = EXCLUDED.in_bed_minutes,
                    awake_minutes = EXCLUDED.awake_minutes,
                    core_light_minutes = EXCLUDED.core_light_minutes,
                    deep_minutes = EXCLUDED.deep_minutes,
                    rem_minutes = EXCLUDED.rem_minutes,
                    sleep_start = EXCLUDED.sleep_start,
                    sleep_end = EXCLUDED.sleep_end,
                    quality_state = EXCLUDED.quality_state,
                    synced_at = NOW(),
                    updated_at = NOW()
                """,
                (
                    str(uuid4()),
                    user_id,
                    profile_id,
                    sleep.localDate,
                    timezone_name,
                    sleep.totalMinutes,
                    sleep.inBedMinutes,
                    sleep.awakeMinutes,
                    sleep.coreLightMinutes,
                    sleep.deepMinutes,
                    sleep.remMinutes,
                    sleep.sleepStart,
                    sleep.sleepEnd,
                    source_platform,
                    sleep.qualityState.value,
                ),
            )


def upsert_sync_state(
    user_id: str,
    platform: str,
    source_platform: str,
    sync_status: str,
    cursor_metadata: dict[str, Any],
    error_code: str | None = None,
    success: bool = False,
) -> datetime | None:
    now = datetime.now(tz=timezone.utc)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO wearable_sync_state (
                    id, user_id, platform, source_platform,
                    last_success_at, last_attempt_at, cursor_metadata,
                    sync_status, last_error_code, created_at, updated_at
                )
                VALUES (
                    %s, %s, %s, %s,
                    %s, %s, %s,
                    %s, %s, NOW(), NOW()
                )
                ON CONFLICT (user_id, source_platform)
                DO UPDATE SET
                    platform = EXCLUDED.platform,
                    last_attempt_at = EXCLUDED.last_attempt_at,
                    last_success_at = CASE
                        WHEN EXCLUDED.last_success_at IS NOT NULL THEN EXCLUDED.last_success_at
                        ELSE wearable_sync_state.last_success_at
                    END,
                    cursor_metadata = EXCLUDED.cursor_metadata,
                    sync_status = EXCLUDED.sync_status,
                    last_error_code = EXCLUDED.last_error_code,
                    updated_at = NOW()
                RETURNING last_success_at
                """,
                (
                    str(uuid4()),
                    user_id,
                    platform,
                    source_platform,
                    now if success else None,
                    now,
                    Json(cursor_metadata),
                    sync_status,
                    error_code,
                ),
            )
            row = cur.fetchone()
            return row["last_success_at"] if row else None


def get_sync_state(user_id: str, source_platform: str | None = None) -> dict[str, Any] | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            if source_platform:
                cur.execute(
                    """
                    SELECT platform, source_platform, last_success_at, last_attempt_at,
                           cursor_metadata, sync_status, last_error_code
                    FROM wearable_sync_state
                    WHERE user_id = %s AND source_platform = %s
                    """,
                    (user_id, source_platform),
                )
            else:
                cur.execute(
                    """
                    SELECT platform, source_platform, last_success_at, last_attempt_at,
                           cursor_metadata, sync_status, last_error_code
                    FROM wearable_sync_state
                    WHERE user_id = %s
                    ORDER BY COALESCE(last_success_at, last_attempt_at) DESC NULLS LAST
                    LIMIT 1
                    """,
                    (user_id,),
                )
            return cur.fetchone()


def list_metrics_for_date(user_id: str, local_date: date) -> list[dict[str, Any]]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT metric_type, unit, value_avg, value_min, value_max,
                       value_latest, value_total, sample_count, quality_state,
                       hrv_method, source_platform, synced_at
                FROM wearable_metric_daily
                WHERE user_id = %s AND local_date = %s
                ORDER BY metric_type
                """,
                (user_id, local_date),
            )
            return list(cur.fetchall())


def list_metrics_window(user_id: str, start_date: date, end_date: date) -> list[dict[str, Any]]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT local_date, metric_type, unit, value_avg, value_min, value_max,
                       value_latest, value_total, sample_count, quality_state, hrv_method
                FROM wearable_metric_daily
                WHERE user_id = %s
                  AND local_date BETWEEN %s AND %s
                  AND quality_state NOT IN ('permission_denied', 'source_unavailable', 'unsupported')
                ORDER BY local_date ASC, metric_type ASC
                """,
                (user_id, start_date, end_date),
            )
            return list(cur.fetchall())


def get_sleep_for_date(user_id: str, local_date: date) -> dict[str, Any] | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT local_date, total_minutes, in_bed_minutes, awake_minutes,
                       core_light_minutes, deep_minutes, rem_minutes,
                       sleep_start, sleep_end, quality_state, timezone
                FROM wearable_sleep_summaries
                WHERE user_id = %s AND local_date = %s
                ORDER BY synced_at DESC
                LIMIT 1
                """,
                (user_id, local_date),
            )
            return cur.fetchone()


def get_sleep_window(user_id: str, start_date: date, end_date: date) -> list[dict[str, Any]]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT local_date, total_minutes, in_bed_minutes, awake_minutes,
                       core_light_minutes, deep_minutes, rem_minutes,
                       sleep_start, sleep_end, quality_state
                FROM wearable_sleep_summaries
                WHERE user_id = %s AND local_date BETWEEN %s AND %s
                ORDER BY local_date ASC
                """,
                (user_id, start_date, end_date),
            )
            return list(cur.fetchall())


def metric_baseline(user_id: str, metric_type: str, days: int = 30) -> float | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT value_avg, value_total, value_latest
                FROM wearable_metric_daily
                WHERE user_id = %s
                  AND metric_type = %s
                  AND local_date >= CURRENT_DATE - (%s || ' days')::INTERVAL
                  AND quality_state IN ('ok', 'partial')
                ORDER BY local_date DESC
                """,
                (user_id, metric_type, days),
            )
            rows = cur.fetchall()
    values: list[float] = []
    for row in rows:
        for key in ("value_avg", "value_total", "value_latest"):
            raw = row.get(key)
            if raw is not None:
                values.append(float(raw))
                break
    if len(values) < 5:
        return None
    values_sorted = sorted(values)
    mid = len(values_sorted) // 2
    if len(values_sorted) % 2:
        return values_sorted[mid]
    return (values_sorted[mid - 1] + values_sorted[mid]) / 2


def count_metric_days(user_id: str, metric_type: str, days: int = 30) -> int:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT COUNT(DISTINCT local_date) AS n
                FROM wearable_metric_daily
                WHERE user_id = %s
                  AND metric_type = %s
                  AND local_date >= CURRENT_DATE - (%s || ' days')::INTERVAL
                  AND quality_state IN ('ok', 'partial')
                """,
                (user_id, metric_type, days),
            )
            row = cur.fetchone()
            return int(row["n"]) if row else 0


def delete_all_health_data(user_id: str) -> tuple[int, int, int, int]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM wearable_metric_daily WHERE user_id = %s", (user_id,))
            metrics = cur.rowcount
            cur.execute("DELETE FROM wearable_sleep_summaries WHERE user_id = %s", (user_id,))
            sleep = cur.rowcount
            cur.execute("DELETE FROM wearable_daily_summaries WHERE user_id = %s", (user_id,))
            daily = cur.rowcount
            cur.execute("DELETE FROM wearable_hourly_summaries WHERE user_id = %s", (user_id,))
            hourly = cur.rowcount
            cur.execute("DELETE FROM wearable_sync_state WHERE user_id = %s", (user_id,))
            cur.execute("DELETE FROM health_insights WHERE user_id = %s", (user_id,))
            return metrics, sleep, daily, hourly


def apply_sync(
    user_id: str,
    payload: HealthSyncRequest,
    consent: object | None = None,
) -> tuple[int, list[str], bool, datetime | None]:
    accepted = 0
    rejected: list[str] = []
    for item in payload.metrics:
        if item.metricType not in CANONICAL_METRICS:
            rejected.append(item.metricType)
            continue
        if consent is not None and not consent_allows_metric(consent, item.metricType):
            rejected.append(f"{item.metricType}:consent_denied")
            continue
        upsert_metric_daily(
            user_id=user_id,
            profile_id=payload.profileId,
            local_date=payload.localDate,
            timezone_name=payload.timezone,
            source_platform=payload.source.value,
            item=item,
        )
        accepted += 1

    sleep_accepted = False
    if payload.sleep is not None:
        has_stages = any(
            getattr(payload.sleep, field) is not None
            for field in ("awakeMinutes", "coreLightMinutes", "deepMinutes", "remMinutes")
        )
        if consent is not None and not consent_allows_sleep_summary(consent, has_stages=has_stages):
            rejected.append("sleep:consent_denied")
        else:
            upsert_sleep_summary(
                user_id=user_id,
                profile_id=payload.profileId,
                timezone_name=payload.timezone,
                source_platform=payload.source.value,
                sleep=payload.sleep,
            )
            sleep_accepted = True

    status = "success" if not rejected else ("partial" if accepted or sleep_accepted else "error")
    last_success = upsert_sync_state(
        user_id=user_id,
        platform=payload.platform.value,
        source_platform=payload.source.value,
        sync_status=status,
        cursor_metadata=payload.cursorMetadata,
        error_code=None if not rejected else "partial_reject",
        success=accepted > 0 or sleep_accepted,
    )
    return accepted, rejected, sleep_accepted, last_success


def mirror_legacy_daily_from_metrics(user_id: str, payload: HealthSyncRequest) -> None:
    """Keep wearables-v1 wide table in sync for personalLoad consumers."""
    by_type = {m.metricType: m for m in payload.metrics}
    steps = by_type.get("steps")
    hr = by_type.get("heart_rate")
    resting = by_type.get("resting_heart_rate")
    hrv = by_type.get("hrv_sdnn") or by_type.get("hrv_rmssd")
    sleep_minutes = None
    if payload.sleep and payload.sleep.totalMinutes is not None:
        sleep_minutes = payload.sleep.totalMinutes
    elif "sleep_total" in by_type and by_type["sleep_total"].valueTotal is not None:
        sleep_minutes = int(by_type["sleep_total"].valueTotal)

    if not any([steps, hr, resting, hrv, sleep_minutes is not None]):
        return

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO wearable_daily_summaries (
                    id, user_id, date, steps_total, heart_rate_avg, heart_rate_min,
                    heart_rate_max, resting_heart_rate_avg, hrv_avg, sleep_minutes,
                    source, created_at, updated_at
                )
                VALUES (
                    %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s,
                    %s, NOW(), NOW()
                )
                ON CONFLICT (user_id, date, source)
                DO UPDATE SET
                    steps_total = COALESCE(EXCLUDED.steps_total, wearable_daily_summaries.steps_total),
                    heart_rate_avg = COALESCE(EXCLUDED.heart_rate_avg, wearable_daily_summaries.heart_rate_avg),
                    heart_rate_min = COALESCE(EXCLUDED.heart_rate_min, wearable_daily_summaries.heart_rate_min),
                    heart_rate_max = COALESCE(EXCLUDED.heart_rate_max, wearable_daily_summaries.heart_rate_max),
                    resting_heart_rate_avg = COALESCE(
                        EXCLUDED.resting_heart_rate_avg,
                        wearable_daily_summaries.resting_heart_rate_avg
                    ),
                    hrv_avg = COALESCE(EXCLUDED.hrv_avg, wearable_daily_summaries.hrv_avg),
                    sleep_minutes = COALESCE(EXCLUDED.sleep_minutes, wearable_daily_summaries.sleep_minutes),
                    updated_at = NOW()
                """,
                (
                    str(uuid4()),
                    user_id,
                    payload.localDate,
                    int(steps.valueTotal) if steps and steps.valueTotal is not None else None,
                    hr.valueAvg if hr else None,
                    hr.valueMin if hr else None,
                    hr.valueMax if hr else None,
                    resting.valueAvg or resting.valueLatest if resting else None,
                    hrv.valueAvg if hrv else None,
                    sleep_minutes,
                    payload.source.value,
                ),
            )
