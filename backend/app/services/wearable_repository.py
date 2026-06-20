from datetime import UTC, datetime
from uuid import uuid4

from app.models.wearable import WearableMetricsResponse, WearableMetricsSubmitRequest
from app.services.db import get_connection


def save_metrics(user_id: str, payload: WearableMetricsSubmitRequest) -> WearableMetricsResponse:
    metric_id = str(uuid4())
    recorded_at = payload.recorded_at or datetime.now(tz=UTC)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO wearable_metrics (
                    id, user_id, profile_id, recorded_at,
                    steps, resting_heart_rate_bpm, hrv_ms,
                    sleep_hours, sleep_quality_score, source
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id, user_id, profile_id, recorded_at,
                          steps, resting_heart_rate_bpm, hrv_ms,
                          sleep_hours, sleep_quality_score, source
                """,
                (
                    metric_id,
                    user_id,
                    payload.profile_id,
                    recorded_at,
                    payload.steps,
                    payload.resting_heart_rate_bpm,
                    payload.hrv_ms,
                    payload.sleep_hours,
                    payload.sleep_quality_score,
                    payload.source,
                ),
            )
            row = cur.fetchone()
    return _row_to_response(row)


def get_latest_metrics(user_id: str, profile_id: str | None = None) -> WearableMetricsResponse | None:
    query = """
        SELECT id, user_id, profile_id, recorded_at,
               steps, resting_heart_rate_bpm, hrv_ms,
               sleep_hours, sleep_quality_score, source
        FROM wearable_metrics
        WHERE user_id = %s
    """
    params: list[str] = [user_id]
    if profile_id:
        query += " AND profile_id = %s"
        params.append(profile_id)
    query += " ORDER BY recorded_at DESC LIMIT 1"

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, tuple(params))
            row = cur.fetchone()
    if row is None:
        return None
    return _row_to_response(row)


def _row_to_response(row: dict) -> WearableMetricsResponse:
    return WearableMetricsResponse(
        id=str(row["id"]),
        user_id=str(row["user_id"]),
        profile_id=str(row["profile_id"]) if row.get("profile_id") else None,
        recorded_at=row["recorded_at"],
        steps=row.get("steps"),
        resting_heart_rate_bpm=row.get("resting_heart_rate_bpm"),
        hrv_ms=float(row["hrv_ms"]) if row.get("hrv_ms") is not None else None,
        sleep_hours=float(row["sleep_hours"]) if row.get("sleep_hours") is not None else None,
        sleep_quality_score=int(row["sleep_quality_score"]) if row.get("sleep_quality_score") is not None else None,
        source=str(row["source"]),
    )
