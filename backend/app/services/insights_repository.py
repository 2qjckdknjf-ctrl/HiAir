from __future__ import annotations

from uuid import uuid4

from app.models.air import PersonalPatternInsight
from app.services.db import get_connection


def get_daily_correlation_samples(profile_id: str, window_days: int) -> list[dict[str, float]]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    DATE(ra.created_at) AS day_key,
                    AVG(COALESCE(es.pm25, 0)) AS pm25,
                    AVG(COALESCE(es.ozone, 0)) AS ozone,
                    AVG(COALESCE(es.temperature_c, 0)) AS temperature,
                    AVG(COALESCE(es.humidity_percent, 0)) AS humidity,
                    AVG(COALESCE(es.aqi, 0)) AS aqi,
                    AVG(CASE WHEN sl.cough THEN 1 ELSE 0 END) AS cough_count,
                    AVG(CASE WHEN sl.wheeze THEN 1 ELSE 0 END) AS wheeze_count,
                    AVG(CASE WHEN sl.headache THEN 1 ELSE 0 END) AS headache_count,
                    AVG(CASE WHEN sl.fatigue THEN 1 ELSE 0 END) AS fatigue_count,
                    AVG(COALESCE(sl.sleep_quality, 3)) AS sleep_quality
                FROM risk_assessments ra
                LEFT JOIN environment_snapshots es
                    ON es.id = ra.environmental_snapshot_id
                LEFT JOIN symptom_logs sl
                    ON sl.profile_id = ra.user_profile_id
                   AND DATE(sl.logged_at) = DATE(ra.created_at)
                WHERE ra.user_profile_id = %s
                  AND ra.created_at >= NOW() - (%s || ' days')::INTERVAL
                GROUP BY DATE(ra.created_at)
                ORDER BY DATE(ra.created_at) ASC
                """,
                (profile_id, window_days),
            )
            rows = cur.fetchall()
    return [_to_sample(row) for row in rows]


def replace_personal_correlations(profile_id: str, window_days: int, items: list[PersonalPatternInsight]) -> None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                DELETE FROM personal_correlations
                WHERE profile_id = %s
                  AND window_days = %s
                """,
                (profile_id, window_days),
            )
            for item in items:
                cur.execute(
                    """
                    INSERT INTO personal_correlations (
                        id,
                        profile_id,
                        factor_a,
                        factor_b,
                        coefficient,
                        p_value,
                        sample_size,
                        window_days,
                        computed_at
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NOW())
                    """,
                    (
                        str(uuid4()),
                        profile_id,
                        item.factorA,
                        item.factorB,
                        item.coefficient,
                        item.pValue,
                        item.sampleSize,
                        window_days,
                    ),
                )


def get_latest_personal_correlations(profile_id: str, window_days: int) -> list[PersonalPatternInsight]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    factor_a,
                    factor_b,
                    coefficient,
                    p_value,
                    sample_size
                FROM personal_correlations
                WHERE profile_id = %s
                  AND window_days = %s
                ORDER BY ABS(coefficient) DESC, computed_at DESC
                LIMIT 20
                """,
                (profile_id, window_days),
            )
            rows = cur.fetchall()
    return [
        PersonalPatternInsight(
            factorA=str(row["factor_a"]),
            factorB=str(row["factor_b"]),
            coefficient=float(row["coefficient"]),
            pValue=float(row["p_value"]),
            sampleSize=int(row["sample_size"]),
            humanReadableText="",
        )
        for row in rows
    ]


def _to_sample(row: dict[str, object]) -> dict[str, float]:
    return {
        "pm25": float(row.get("pm25") or 0.0),
        "ozone": float(row.get("ozone") or 0.0),
        "temperature": float(row.get("temperature") or 0.0),
        "humidity": float(row.get("humidity") or 0.0),
        "aqi": float(row.get("aqi") or 0.0),
        "cough_count": float(row.get("cough_count") or 0.0),
        "wheeze_count": float(row.get("wheeze_count") or 0.0),
        "headache_count": float(row.get("headache_count") or 0.0),
        "fatigue_count": float(row.get("fatigue_count") or 0.0),
        "sleep_quality": float(row.get("sleep_quality") or 3.0),
    }
