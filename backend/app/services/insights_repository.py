from __future__ import annotations

from uuid import uuid4

from app.models.air import PersonalPatternInsight
from app.services.db import get_connection


def get_daily_correlation_samples(profile_id: str, window_days: int) -> list[dict[str, float | None]]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    DATE(ra.created_at) AS day_key,
                    AVG(es.pm25) AS pm25,
                    AVG(es.ozone) AS ozone,
                    AVG(es.temperature_c) AS temperature,
                    AVG(es.humidity_percent) AS humidity,
                    AVG(es.aqi) AS aqi,
                    AVG(
                        CASE
                            WHEN sl.id IS NULL THEN NULL
                            WHEN sl.cough THEN 1.0
                            ELSE 0.0
                        END
                    ) AS cough_count,
                    AVG(
                        CASE
                            WHEN sl.id IS NULL THEN NULL
                            WHEN sl.wheeze THEN 1.0
                            ELSE 0.0
                        END
                    ) AS wheeze_count,
                    AVG(
                        CASE
                            WHEN sl.id IS NULL THEN NULL
                            WHEN sl.headache THEN 1.0
                            ELSE 0.0
                        END
                    ) AS headache_count,
                    AVG(
                        CASE
                            WHEN sl.id IS NULL THEN NULL
                            WHEN sl.fatigue THEN 1.0
                            ELSE 0.0
                        END
                    ) AS fatigue_count,
                    AVG(sl.sleep_quality) AS sleep_quality
                FROM risk_assessments ra
                LEFT JOIN environment_snapshots es
                    ON es.id = ra.environmental_snapshot_id
                LEFT JOIN symptom_logs sl
                    ON sl.profile_id = ra.user_profile_id
                   AND DATE(COALESCE(sl.logged_at, sl.timestamp_utc)) = DATE(ra.created_at)
                   AND (sl.deleted_at IS NULL)
                WHERE ra.user_profile_id = %s
                  AND ra.created_at >= NOW() - (%s || ' days')::INTERVAL
                GROUP BY DATE(ra.created_at)
                ORDER BY DATE(ra.created_at) ASC
                """,
                (profile_id, window_days),
            )
            rows = cur.fetchall()

            # Enrich with wearable aggregates for the profile owner when available.
            cur.execute(
                """
                SELECT p.user_id
                FROM profiles p
                WHERE p.id = %s
                """,
                (profile_id,),
            )
            owner = cur.fetchone()
            wearable_by_day: dict = {}
            if owner and owner.get("user_id"):
                cur.execute(
                    """
                    SELECT date,
                           steps_total,
                           resting_heart_rate_avg,
                           sleep_minutes
                    FROM wearable_daily_summaries
                    WHERE user_id = %s
                      AND date >= CURRENT_DATE - (%s || ' days')::INTERVAL
                    """,
                    (str(owner["user_id"]), window_days),
                )
                for wrow in cur.fetchall():
                    wearable_by_day[wrow["date"]] = wrow

    samples = []
    for row in rows:
        sample = _to_sample(row)
        wrow = wearable_by_day.get(row["day_key"])
        if wrow:
            sample["steps"] = _nullable(wrow.get("steps_total"))
            sample["resting_heart_rate"] = _nullable(wrow.get("resting_heart_rate_avg"))
            sample["sleep_minutes"] = _nullable(wrow.get("sleep_minutes"))
        else:
            sample["steps"] = None
            sample["resting_heart_rate"] = None
            sample["sleep_minutes"] = None
        samples.append(sample)
    return samples


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


def _to_sample(row: dict[str, object]) -> dict[str, float | None]:
    return {
        "pm25": _nullable(row.get("pm25")),
        "ozone": _nullable(row.get("ozone")),
        "temperature": _nullable(row.get("temperature")),
        "humidity": _nullable(row.get("humidity")),
        "aqi": _nullable(row.get("aqi")),
        "cough_count": _nullable(row.get("cough_count")),
        "wheeze_count": _nullable(row.get("wheeze_count")),
        "headache_count": _nullable(row.get("headache_count")),
        "fatigue_count": _nullable(row.get("fatigue_count")),
        "sleep_quality": _nullable(row.get("sleep_quality")),
    }


def _nullable(value: object) -> float | None:
    if value is None:
        return None
    return float(value)
