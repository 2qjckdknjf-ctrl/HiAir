from app.models.insights import PersonalInsightItem, PersonalPatternsResponse
from app.services.db import get_connection
import app.services.wearable_repository as wearable_repository


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
                    AVG(e.aqi) FILTER (
                        WHERE s.cough OR s.wheeze OR s.headache OR s.fatigue
                    ) AS symptom_aqi,
                    AVG(e.aqi) FILTER (
                        WHERE NOT (s.cough OR s.wheeze OR s.headache OR s.fatigue)
                    ) AS clean_aqi,
                    COUNT(*) AS total
                FROM symptom_logs s
                JOIN LATERAL (
                    SELECT r.snapshot_id
                    FROM risk_scores r
                    WHERE r.profile_id = s.profile_id
                      AND r.snapshot_id IS NOT NULL
                      AND r.created_at <= s.timestamp_utc
                    ORDER BY r.created_at DESC
                    LIMIT 1
                ) matched_risk ON TRUE
                JOIN environment_snapshots e ON e.id = matched_risk.snapshot_id
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
    metrics = wearable_repository.get_latest_metrics(user_id=user_id, profile_id=profile_id)
    if metrics is None or metrics.resting_heart_rate_bpm is None:
        return None

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT AVG(temperature_c) AS avg_temp
                FROM environment_snapshots e
                JOIN risk_scores r ON r.snapshot_id = e.id
                WHERE r.profile_id = %s
                  AND r.created_at >= NOW() - INTERVAL '14 days'
                """,
                (profile_id,),
            )
            row = cur.fetchone()
    if not row or row.get("avg_temp") is None:
        return None
    avg_temp = float(row["avg_temp"])
    if avg_temp < 28 or metrics.resting_heart_rate_bpm < 80:
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
