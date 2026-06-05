from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

from app.models.wearable import (
    WearableConsentRequest,
    WearableConsentResponse,
    WearableDailySummaryRequest,
    WearableDailySummaryResponse,
    WearableHourlySummaryRequest,
    WearableSource,
)
from app.services.db import get_connection


def _row_to_consent(row: dict) -> WearableConsentResponse:
    revoked_at = row.get("revoked_at")
    accepted_at = row.get("accepted_at")
    is_active = accepted_at is not None and revoked_at is None
    return WearableConsentResponse(
        id=str(row["id"]),
        userId=str(row["user_id"]),
        platform=row["platform"],
        source=row["source"],
        stepsEnabled=bool(row["steps_enabled"]),
        heartRateEnabled=bool(row["heart_rate_enabled"]),
        restingHeartRateEnabled=bool(row["resting_heart_rate_enabled"]),
        hrvEnabled=bool(row["hrv_enabled"]),
        sleepEnabled=bool(row["sleep_enabled"]),
        consentVersion=row["consent_version"],
        acceptedAt=accepted_at,
        revokedAt=revoked_at,
        isActive=is_active,
    )


def upsert_consent(user_id: str, payload: WearableConsentRequest) -> WearableConsentResponse:
    now = datetime.now(tz=UTC)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO health_data_consents (
                    user_id,
                    platform,
                    source,
                    steps_enabled,
                    heart_rate_enabled,
                    resting_heart_rate_enabled,
                    hrv_enabled,
                    sleep_enabled,
                    consent_version,
                    accepted_at,
                    revoked_at,
                    updated_at
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NULL, %s)
                ON CONFLICT (user_id, source)
                DO UPDATE SET
                    platform = EXCLUDED.platform,
                    steps_enabled = EXCLUDED.steps_enabled,
                    heart_rate_enabled = EXCLUDED.heart_rate_enabled,
                    resting_heart_rate_enabled = EXCLUDED.resting_heart_rate_enabled,
                    hrv_enabled = EXCLUDED.hrv_enabled,
                    sleep_enabled = EXCLUDED.sleep_enabled,
                    consent_version = EXCLUDED.consent_version,
                    accepted_at = EXCLUDED.accepted_at,
                    revoked_at = NULL,
                    updated_at = EXCLUDED.updated_at
                RETURNING *
                """,
                (
                    user_id,
                    payload.platform.value,
                    payload.source.value,
                    payload.stepsEnabled,
                    payload.heartRateEnabled,
                    payload.restingHeartRateEnabled,
                    payload.hrvEnabled,
                    payload.sleepEnabled,
                    payload.consentVersion,
                    now,
                    now,
                ),
            )
            row = cur.fetchone()
    return _row_to_consent(row)


def revoke_consent(user_id: str, source: WearableSource | None = None) -> WearableConsentResponse | None:
    now = datetime.now(tz=UTC)
    with get_connection() as conn:
        with conn.cursor() as cur:
            if source is not None:
                cur.execute(
                    """
                    UPDATE health_data_consents
                    SET revoked_at = %s, updated_at = %s
                    WHERE user_id = %s AND source = %s AND revoked_at IS NULL
                    RETURNING *
                    """,
                    (now, now, user_id, source.value),
                )
            else:
                cur.execute(
                    """
                    UPDATE health_data_consents
                    SET revoked_at = %s, updated_at = %s
                    WHERE user_id = %s AND revoked_at IS NULL
                    RETURNING *
                    """,
                    (now, now, user_id),
                )
            row = cur.fetchone()
    return _row_to_consent(row) if row else None


def get_active_consent(user_id: str, source: WearableSource | None = None) -> WearableConsentResponse | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            if source is not None:
                cur.execute(
                    """
                    SELECT * FROM health_data_consents
                    WHERE user_id = %s AND source = %s
                      AND accepted_at IS NOT NULL AND revoked_at IS NULL
                    ORDER BY accepted_at DESC
                    LIMIT 1
                    """,
                    (user_id, source.value),
                )
            else:
                cur.execute(
                    """
                    SELECT * FROM health_data_consents
                    WHERE user_id = %s
                      AND accepted_at IS NOT NULL AND revoked_at IS NULL
                    ORDER BY accepted_at DESC
                    LIMIT 1
                    """,
                    (user_id,),
                )
            row = cur.fetchone()
    return _row_to_consent(row) if row else None


def get_latest_consent(user_id: str) -> WearableConsentResponse | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT * FROM health_data_consents
                WHERE user_id = %s
                ORDER BY updated_at DESC
                LIMIT 1
                """,
                (user_id,),
            )
            row = cur.fetchone()
    return _row_to_consent(row) if row else None


def has_active_consent(user_id: str, source: WearableSource) -> bool:
    consent = get_active_consent(user_id, source)
    return consent is not None and consent.isActive


def upsert_daily_summary(user_id: str, payload: WearableDailySummaryRequest) -> WearableDailySummaryResponse:
    now = datetime.now(tz=UTC)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO wearable_daily_summaries (
                    user_id,
                    date,
                    steps_total,
                    steps_goal,
                    heart_rate_avg,
                    heart_rate_min,
                    heart_rate_max,
                    resting_heart_rate_avg,
                    resting_heart_rate_delta,
                    hrv_avg,
                    sleep_minutes,
                    source,
                    updated_at
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (user_id, date, source)
                DO UPDATE SET
                    steps_total = COALESCE(EXCLUDED.steps_total, wearable_daily_summaries.steps_total),
                    steps_goal = COALESCE(EXCLUDED.steps_goal, wearable_daily_summaries.steps_goal),
                    heart_rate_avg = COALESCE(EXCLUDED.heart_rate_avg, wearable_daily_summaries.heart_rate_avg),
                    heart_rate_min = COALESCE(EXCLUDED.heart_rate_min, wearable_daily_summaries.heart_rate_min),
                    heart_rate_max = COALESCE(EXCLUDED.heart_rate_max, wearable_daily_summaries.heart_rate_max),
                    resting_heart_rate_avg = COALESCE(
                        EXCLUDED.resting_heart_rate_avg, wearable_daily_summaries.resting_heart_rate_avg
                    ),
                    resting_heart_rate_delta = COALESCE(
                        EXCLUDED.resting_heart_rate_delta, wearable_daily_summaries.resting_heart_rate_delta
                    ),
                    hrv_avg = COALESCE(EXCLUDED.hrv_avg, wearable_daily_summaries.hrv_avg),
                    sleep_minutes = COALESCE(EXCLUDED.sleep_minutes, wearable_daily_summaries.sleep_minutes),
                    updated_at = EXCLUDED.updated_at
                RETURNING *
                """,
                (
                    user_id,
                    payload.date,
                    payload.stepsTotal,
                    payload.stepsGoal,
                    payload.heartRateAvg,
                    payload.heartRateMin,
                    payload.heartRateMax,
                    payload.restingHeartRateAvg,
                    payload.restingHeartRateDelta,
                    payload.hrvAvg,
                    payload.sleepMinutes,
                    payload.source.value,
                    now,
                ),
            )
            row = cur.fetchone()
    return _row_to_daily(row)


def upsert_hourly_summary(user_id: str, payload: WearableHourlySummaryRequest) -> dict:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO wearable_hourly_summaries (
                    user_id,
                    hour_start,
                    steps_total,
                    heart_rate_avg,
                    heart_rate_max,
                    source
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (user_id, hour_start, source)
                DO UPDATE SET
                    steps_total = COALESCE(EXCLUDED.steps_total, wearable_hourly_summaries.steps_total),
                    heart_rate_avg = COALESCE(EXCLUDED.heart_rate_avg, wearable_hourly_summaries.heart_rate_avg),
                    heart_rate_max = COALESCE(EXCLUDED.heart_rate_max, wearable_hourly_summaries.heart_rate_max)
                RETURNING id, hour_start, steps_total, heart_rate_avg, heart_rate_max, source
                """,
                (
                    user_id,
                    payload.hourStart,
                    payload.stepsTotal,
                    payload.heartRateAvg,
                    payload.heartRateMax,
                    payload.source.value,
                ),
            )
            return dict(cur.fetchone())


def get_daily_summary(user_id: str, target_date: date, source: WearableSource | None = None) -> WearableDailySummaryResponse | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            if source is not None:
                cur.execute(
                    """
                    SELECT * FROM wearable_daily_summaries
                    WHERE user_id = %s AND date = %s AND source = %s
                    """,
                    (user_id, target_date, source.value),
                )
            else:
                cur.execute(
                    """
                    SELECT * FROM wearable_daily_summaries
                    WHERE user_id = %s AND date = %s
                    ORDER BY updated_at DESC
                    LIMIT 1
                    """,
                    (user_id, target_date),
                )
            row = cur.fetchone()
    return _row_to_daily(row) if row else None


def sum_steps_since(user_id: str, since: datetime, source: WearableSource | None = None) -> int:
    with get_connection() as conn:
        with conn.cursor() as cur:
            if source is not None:
                cur.execute(
                    """
                    SELECT COALESCE(SUM(steps_total), 0) AS total
                    FROM wearable_hourly_summaries
                    WHERE user_id = %s AND source = %s AND hour_start >= %s
                    """,
                    (user_id, source.value, since),
                )
            else:
                cur.execute(
                    """
                    SELECT COALESCE(SUM(steps_total), 0) AS total
                    FROM wearable_hourly_summaries
                    WHERE user_id = %s AND hour_start >= %s
                    """,
                    (user_id, since),
                )
            row = cur.fetchone()
    return int(row["total"]) if row else 0


def resting_hr_baseline(user_id: str, days: int) -> float | None:
    since = date.today() - timedelta(days=days)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT AVG(resting_heart_rate_avg) AS baseline
                FROM wearable_daily_summaries
                WHERE user_id = %s
                  AND date >= %s
                  AND resting_heart_rate_avg IS NOT NULL
                """,
                (user_id, since),
            )
            row = cur.fetchone()
    if row is None or row["baseline"] is None:
        return None
    return float(row["baseline"])


def delete_all_summaries(user_id: str) -> tuple[int, int]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM wearable_hourly_summaries WHERE user_id = %s", (user_id,))
            hourly_deleted = cur.rowcount
            cur.execute("DELETE FROM wearable_daily_summaries WHERE user_id = %s", (user_id,))
            daily_deleted = cur.rowcount
    return daily_deleted, hourly_deleted


def _row_to_daily(row: dict) -> WearableDailySummaryResponse:
    return WearableDailySummaryResponse(
        id=str(row["id"]),
        date=row["date"],
        stepsTotal=row.get("steps_total"),
        stepsGoal=row.get("steps_goal"),
        heartRateAvg=float(row["heart_rate_avg"]) if row.get("heart_rate_avg") is not None else None,
        heartRateMin=float(row["heart_rate_min"]) if row.get("heart_rate_min") is not None else None,
        heartRateMax=float(row["heart_rate_max"]) if row.get("heart_rate_max") is not None else None,
        restingHeartRateAvg=float(row["resting_heart_rate_avg"])
        if row.get("resting_heart_rate_avg") is not None
        else None,
        restingHeartRateDelta=float(row["resting_heart_rate_delta"])
        if row.get("resting_heart_rate_delta") is not None
        else None,
        source=row["source"],
    )
