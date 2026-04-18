from datetime import datetime, timezone
from uuid import uuid4

from psycopg.types.json import Jsonb

from app.models.risk import EnvironmentSnapshot, RiskEstimateResponse, SymptomInput
from app.services.db import get_connection


def save_environment_snapshot(environment: EnvironmentSnapshot) -> str:
    snapshot_id = str(uuid4())
    timestamp_utc = datetime.now(timezone.utc)
    region_key = "ad-hoc"
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO environment_snapshots
                (id, region_key, timestamp_utc, temperature_c, humidity_percent, aqi, pm25, ozone, source)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    snapshot_id,
                    region_key,
                    timestamp_utc,
                    environment.temperature_c,
                    environment.humidity_percent,
                    environment.aqi,
                    environment.pm25,
                    environment.ozone,
                    environment.source,
                ),
            )
    return snapshot_id


def save_risk_score(
    profile_id: str,
    risk: RiskEstimateResponse,
    snapshot_id: str | None,
) -> str:
    risk_id = str(uuid4())
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO risk_scores (id, profile_id, snapshot_id, score_value, risk_level, recommendations_json)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    risk_id,
                    profile_id,
                    snapshot_id,
                    risk.score,
                    risk.level,
                    Jsonb(risk.recommendations),
                ),
            )
    return risk_id


def get_risk_history(profile_id: str, limit: int = 20) -> list[dict[str, str | int | list[str]]]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, profile_id, score_value, risk_level, recommendations_json, created_at
                FROM risk_scores
                WHERE profile_id = %s
                ORDER BY created_at DESC
                LIMIT %s
                """,
                (profile_id, limit),
            )
            rows = cur.fetchall()
    return [
        {
            "id": str(row["id"]),
            "profile_id": str(row["profile_id"]),
            "score_value": row["score_value"],
            "risk_level": row["risk_level"],
            "recommendations": list(row["recommendations_json"]),
            "created_at": row["created_at"].isoformat(),
        }
        for row in rows
    ]


def create_symptom_log(profile_id: str, symptom: SymptomInput) -> dict[str, str]:
    log_id = str(uuid4())
    timestamp_utc = datetime.now(timezone.utc)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO symptom_logs
                (id, profile_id, timestamp_utc, cough, wheeze, headache, fatigue, sleep_quality)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    log_id,
                    profile_id,
                    timestamp_utc,
                    symptom.cough,
                    symptom.wheeze,
                    symptom.headache,
                    symptom.fatigue,
                    symptom.sleep_quality,
                ),
            )
    return {
        "id": log_id,
        "profile_id": profile_id,
        "timestamp_utc": timestamp_utc.isoformat(),
    }


def get_recent_symptom_stats(profile_id: str, hours: int = 48) -> dict[str, int]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    SUM(CASE WHEN cough THEN 1 ELSE 0 END) AS cough_count,
                    SUM(CASE WHEN wheeze THEN 1 ELSE 0 END) AS wheeze_count,
                    SUM(CASE WHEN headache THEN 1 ELSE 0 END) AS headache_count,
                    SUM(CASE WHEN fatigue THEN 1 ELSE 0 END) AS fatigue_count,
                    COUNT(*) AS total_logs
                FROM symptom_logs
                WHERE profile_id = %s
                  AND timestamp_utc >= NOW() - (%s || ' hours')::INTERVAL
                """,
                (profile_id, hours),
            )
            row = cur.fetchone()

    if row is None:
        return {
            "cough_count": 0,
            "wheeze_count": 0,
            "headache_count": 0,
            "fatigue_count": 0,
            "total_logs": 0,
        }

    return {
        "cough_count": int(row["cough_count"] or 0),
        "wheeze_count": int(row["wheeze_count"] or 0),
        "headache_count": int(row["headache_count"] or 0),
        "fatigue_count": int(row["fatigue_count"] or 0),
        "total_logs": int(row["total_logs"] or 0),
    }


def get_latest_sleep_quality(profile_id: str) -> int:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT sleep_quality
                FROM symptom_logs
                WHERE profile_id = %s
                ORDER BY timestamp_utc DESC
                LIMIT 1
                """,
                (profile_id,),
            )
            row = cur.fetchone()
    if row is None:
        return 3
    return int(row["sleep_quality"])
