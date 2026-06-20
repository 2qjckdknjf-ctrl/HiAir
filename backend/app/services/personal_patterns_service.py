from app.models.insights import PersonalInsightItem, PersonalPatternsResponse
from app.services.db import get_connection


MINIMUM_DAYS = 7


def _days_observed(profile_id: str) -> int:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT COUNT(DISTINCT DATE(timestamp_utc)) AS day_count
                FROM symptom_logs
                WHERE profile_id = %s
                  AND timestamp_utc >= NOW() - INTERVAL '14 days'
                """,
                (profile_id,),
            )
            row = cur.fetchone()
    return int(row["day_count"] or 0) if row else 0


def _symptom_aqi_insight(profile_id: str) -> PersonalInsightItem | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    AVG(matched.aqi) FILTER (
                        WHERE s.cough OR s.wheeze OR s.headache OR s.fatigue
                    ) AS symptom_aqi,
                    AVG(matched.aqi) FILTER (
                        WHERE NOT (s.cough OR s.wheeze OR s.headache OR s.fatigue)
                    ) AS clean_aqi,
                    COUNT(matched.aqi) AS total
                FROM symptom_logs s
                LEFT JOIN LATERAL (
                    SELECT e.aqi
                    FROM risk_scores r
                    JOIN environment_snapshots e ON e.id = r.snapshot_id
                    WHERE r.profile_id = s.profile_id
                      AND e.timestamp_utc BETWEEN s.timestamp_utc - INTERVAL '6 hours'
                                              AND s.timestamp_utc + INTERVAL '6 hours'
                    ORDER BY ABS(EXTRACT(EPOCH FROM (e.timestamp_utc - s.timestamp_utc)))
                    LIMIT 1
                ) matched ON TRUE
                WHERE s.profile_id = %s
                  AND s.timestamp_utc >= NOW() - INTERVAL '14 days'
                """,
                (profile_id,),
            )
            row = cur.fetchone()
    if not row or int(row["total"] or 0) < 3:
        return None
    symptom_aqi = row.get("symptom_aqi")
    clean_aqi = row.get("clean_aqi")
    if symptom_aqi is None or clean_aqi is None:
        return None
    if float(symptom_aqi) <= float(clean_aqi) + 10:
        return None
    threshold = int(round(float(symptom_aqi)))
    return PersonalInsightItem(
        insight_type="symptoms_vs_aqi",
        title_ru="Симптомы и качество воздуха",
        title_en="Symptoms and air quality",
        body_ru=(
            f"За последние дни симптомы чаще отмечались при AQI выше {threshold}. "
            "Это wellness-наблюдение, не медицинский вывод."
        ),
        body_en=(
            f"In recent days symptoms were more common when AQI was above {threshold}. "
            "This is wellness guidance, not medical advice."
        ),
        confidence="medium",
    )


def _time_of_day_insight(profile_id: str) -> PersonalInsightItem | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    EXTRACT(HOUR FROM created_at) AS hour_bucket,
                    AVG(score_value) AS avg_score,
                    COUNT(*) AS cnt
                FROM risk_scores
                WHERE profile_id = %s
                  AND created_at >= NOW() - INTERVAL '14 days'
                GROUP BY hour_bucket
                HAVING COUNT(*) >= 2
                ORDER BY avg_score DESC
                LIMIT 1
                """,
                (profile_id,),
            )
            row = cur.fetchone()
    if not row:
        return None
    hour = int(row["hour_bucket"])
    end_hour = (hour + 3) % 24
    return PersonalInsightItem(
        insight_type="risk_time_of_day",
        title_ru="Пик риска по времени суток",
        title_en="Risk peak by time of day",
        body_ru=(
            f"За последние дни риск чаще был выше около {hour:02d}:00–{end_hour:02d}:00. "
            "Планируйте активность в более спокойные часы."
        ),
        body_en=(
            f"Recently risk tended to be higher around {hour:02d}:00–{end_hour:02d}:00. "
            "Plan activity for calmer hours."
        ),
        confidence="medium",
    )


def _wearable_heat_insight(user_id: str, profile_id: str) -> PersonalInsightItem | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                WITH daily_env AS (
                    SELECT
                        DATE(e.timestamp_utc) AS day,
                        AVG(e.temperature_c) AS avg_temp
                    FROM environment_snapshots e
                    JOIN risk_scores r ON r.snapshot_id = e.id
                    WHERE r.profile_id = %s
                      AND e.timestamp_utc >= NOW() - INTERVAL '14 days'
                    GROUP BY DATE(e.timestamp_utc)
                ),
                daily_hr AS (
                    SELECT
                        DATE(recorded_at) AS day,
                        AVG(resting_heart_rate_bpm) AS avg_resting_hr
                    FROM wearable_metrics
                    WHERE user_id = %s
                      AND profile_id = %s
                      AND recorded_at >= NOW() - INTERVAL '14 days'
                      AND resting_heart_rate_bpm IS NOT NULL
                    GROUP BY DATE(recorded_at)
                ),
                paired_days AS (
                    SELECT e.day, e.avg_temp, h.avg_resting_hr
                    FROM daily_env e
                    JOIN daily_hr h ON h.day = e.day
                )
                SELECT
                    COUNT(*) FILTER (WHERE avg_temp >= 28) AS hot_days,
                    COUNT(*) FILTER (WHERE avg_temp < 28) AS cool_days,
                    AVG(avg_resting_hr) FILTER (WHERE avg_temp >= 28) AS hot_hr,
                    AVG(avg_resting_hr) FILTER (WHERE avg_temp < 28) AS cool_hr
                FROM paired_days
                """,
                (profile_id, user_id, profile_id),
            )
            row = cur.fetchone()
    if not row:
        return None
    hot_days = int(row["hot_days"] or 0)
    cool_days = int(row["cool_days"] or 0)
    hot_hr = row.get("hot_hr")
    cool_hr = row.get("cool_hr")
    if hot_days < 2 or cool_days < 2 or hot_hr is None or cool_hr is None:
        return None
    if float(hot_hr) < 80 or float(hot_hr) <= float(cool_hr) + 5:
        return None
    return PersonalInsightItem(
        insight_type="wearable_heat_correlation",
        title_ru="Пульс и жара",
        title_en="Heart rate and heat",
        body_ru=(
            "При более жарких днях ваш пульс в покое был выше обычного. "
            "Снижайте нагрузку в жару — это wellness-подсказка."
        ),
        body_en=(
            "On hotter days your resting heart rate was higher than usual. "
            "Reduce exertion in heat — wellness guidance only."
        ),
        confidence="low",
    )


def build_personal_patterns(profile_id: str, user_id: str) -> PersonalPatternsResponse:
    days = _days_observed(profile_id)
    if days < MINIMUM_DAYS:
        return PersonalPatternsResponse(
            profile_id=profile_id,
            days_observed=days,
            minimum_days_required=MINIMUM_DAYS,
            ready=False,
            status_ru=f"Нужно больше дней наблюдений ({days}/{MINIMUM_DAYS}).",
            status_en=f"More observation days needed ({days}/{MINIMUM_DAYS}).",
            insights=[],
        )

    insights: list[PersonalInsightItem] = []
    for builder in (_symptom_aqi_insight, _time_of_day_insight):
        item = builder(profile_id)
        if item:
            insights.append(item)
    wearable_item = _wearable_heat_insight(user_id, profile_id)
    if wearable_item:
        insights.append(wearable_item)

    return PersonalPatternsResponse(
        profile_id=profile_id,
        days_observed=days,
        minimum_days_required=MINIMUM_DAYS,
        ready=len(insights) > 0,
        status_ru="Персональные инсайты готовы." if insights else "Пока недостаточно данных для инсайтов.",
        status_en="Personal insights are ready." if insights else "Not enough data for insights yet.",
        insights=insights[:3],
    )
