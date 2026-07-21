"""Explainable, statistics-first personal health analytics.

Wellness language only. No causal claims. Missing data is never treated as zero.
"""

from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from statistics import median
from typing import Any

from app.models.health_intelligence import InsightCard
from app.services import health_sync_repository
from app.services.db import get_connection
from app.services.localization import normalize_language
import app.services.wearable_repository as wearable_repository

MIN_TREND_DAYS = 7
MIN_ASSOCIATION_SYMPTOM_DAYS = 5
MIN_STRONGER_DAYS = 14
MIN_TREND_COMPARE_POINTS = 14


def build_insights_bundle(
    *,
    user_id: str,
    profile_id: str,
    window_days: int = 30,
    language: str = "ru",
    require_active_consent: bool = True,
) -> dict[str, Any]:
    lang = normalize_language(language)
    end = date.today()
    start = end - timedelta(days=window_days - 1)

    if require_active_consent:
        try:
            consent = wearable_repository.get_active_consent(user_id)
        except Exception:
            consent = None
        if consent is None or not getattr(consent, "isActive", True):
            return {
                "profileId": profile_id,
                "generatedAt": datetime.now(tz=timezone.utc),
                "today": {"localDate": end.isoformat()},
                "trends": [],
                "associations": [],
                "insufficientData": [
                    {
                        "message": _t(lang, "insufficient_consent"),
                        "have": 0,
                        "need": 1,
                    }
                ],
                "healthDataStatus": {
                    "metricDays": 0,
                    "syncStatus": "pending",
                    "consentActive": False,
                },
            }

    metrics = health_sync_repository.list_metrics_window(user_id, start, end)
    sleep_rows = health_sync_repository.get_sleep_window(user_id, start, end)
    env_by_day = _load_environment_by_day(profile_id, start, end)
    symptoms_by_day = _load_symptoms_by_day(profile_id, start, end)
    risk_by_day = _load_risk_by_day(profile_id, start, end)

    today_metrics = [m for m in metrics if m["local_date"] == end]
    today_sleep = next((s for s in sleep_rows if s["local_date"] == end), None)

    today = {
        "localDate": end.isoformat(),
        "sleepMinutes": today_sleep.get("total_minutes") if today_sleep else None,
        "sleepDeepMinutes": today_sleep.get("deep_minutes") if today_sleep else None,
        "sleepRemMinutes": today_sleep.get("rem_minutes") if today_sleep else None,
        "sleepCoreMinutes": today_sleep.get("core_light_minutes") if today_sleep else None,
        "sleepAwakeMinutes": today_sleep.get("awake_minutes") if today_sleep else None,
        "sleepInBedMinutes": today_sleep.get("in_bed_minutes") if today_sleep else None,
        "steps": _metric_value(today_metrics, "steps"),
        "distanceMeters": _metric_value(today_metrics, "distance_walking_running"),
        "activeEnergyKcal": _metric_value(today_metrics, "active_energy"),
        "exerciseMinutes": _metric_value(today_metrics, "exercise_minutes"),
        "standMinutes": _metric_value(today_metrics, "stand_minutes"),
        "flightsClimbed": _metric_value(today_metrics, "flights_climbed"),
        "workoutCount": _metric_value(today_metrics, "workout_count"),
        "workoutDurationMinutes": _metric_value(today_metrics, "workout_duration"),
        "heartRate": _metric_value(today_metrics, "heart_rate"),
        "restingHeartRate": _metric_value(today_metrics, "resting_heart_rate"),
        "walkingHeartRate": _metric_value(today_metrics, "walking_heart_rate_avg"),
        "hrv": _metric_value(today_metrics, "hrv_sdnn") or _metric_value(today_metrics, "hrv_rmssd"),
        "hrvMethod": "sdnn" if _metric_value(today_metrics, "hrv_sdnn") is not None else (
            "rmssd" if _metric_value(today_metrics, "hrv_rmssd") is not None else None
        ),
        "respiratoryRate": _metric_value(today_metrics, "respiratory_rate"),
        "oxygenSaturation": _metric_value(today_metrics, "oxygen_saturation"),
        "bodyTemperature": _metric_value(today_metrics, "body_temperature"),
        "wristTemperature": _metric_value(today_metrics, "wrist_temperature"),
        "vo2Max": _metric_value(today_metrics, "vo2_max"),
        "environment": env_by_day.get(end, {}),
        "symptoms": symptoms_by_day.get(end, []),
        "risk": risk_by_day.get(end),
    }

    trends = _compute_trends(metrics, sleep_rows, lang, window_days)
    associations = _compute_associations(env_by_day, symptoms_by_day, metrics, sleep_rows, lang, window_days)
    insufficient = _insufficient_data_cards(
        metrics=metrics,
        sleep_rows=sleep_rows,
        symptoms_by_day=symptoms_by_day,
        lang=lang,
        window_days=window_days,
    )
    status = _health_data_status(user_id, metrics, sleep_rows)

    return {
        "profileId": profile_id,
        "generatedAt": datetime.now(tz=timezone.utc),
        "today": today,
        "trends": trends,
        "associations": associations,
        "insufficientData": insufficient,
        "healthDataStatus": status,
    }


def build_timeline(
    *,
    user_id: str,
    profile_id: str,
    window_days: int = 30,
) -> list[dict[str, Any]]:
    end = date.today()
    start = end - timedelta(days=window_days - 1)
    metrics = health_sync_repository.list_metrics_window(user_id, start, end)
    sleep_rows = health_sync_repository.get_sleep_window(user_id, start, end)
    env_by_day = _load_environment_by_day(profile_id, start, end)
    symptoms_by_day = _load_symptoms_by_day(profile_id, start, end)
    risk_by_day = _load_risk_by_day(profile_id, start, end)

    metrics_by_day: dict[date, dict[str, float | None]] = defaultdict(dict)
    for row in metrics:
        day = row["local_date"]
        value = _row_primary_value(row)
        metrics_by_day[day][row["metric_type"]] = value

    sleep_by_day = {row["local_date"]: row.get("total_minutes") for row in sleep_rows}

    points = []
    cursor = start
    while cursor <= end:
        health = dict(metrics_by_day.get(cursor, {}))
        if cursor in sleep_by_day:
            health["sleep_total"] = sleep_by_day[cursor]
        env = env_by_day.get(cursor, {})
        symptoms = symptoms_by_day.get(cursor, [])
        risk = risk_by_day.get(cursor)
        points.append(
            {
                "localDate": cursor,
                "environment": env,
                "health": health,
                "symptoms": symptoms,
                "riskScore": risk["score"] if risk else None,
                "riskLevel": risk["level"] if risk else None,
                "completeness": {
                    "environment": any(v is not None for v in env.values()),
                    "health": any(v is not None for v in health.values()),
                    "symptoms": len(symptoms) > 0,
                    "risk": risk is not None,
                },
            }
        )
        cursor += timedelta(days=1)
    return points


def _compute_trends(
    metrics: list[dict[str, Any]],
    sleep_rows: list[dict[str, Any]],
    lang: str,
    window_days: int,
) -> list[InsightCard]:
    cards: list[InsightCard] = []
    trend_specs = (
        ("steps", "steps"),
        ("distance_walking_running", "distance"),
        ("active_energy", "active_energy"),
        ("exercise_minutes", "exercise"),
        ("workout_duration", "workout"),
        ("resting_heart_rate", "resting_hr"),
        ("hrv_sdnn", "hrv"),
        ("hrv_rmssd", "hrv"),
        ("sleep_total", "sleep"),
        ("oxygen_saturation", "spo2"),
        ("respiratory_rate", "resp"),
    )
    seen_hrv = False
    for metric_type, title_key in trend_specs:
        if metric_type.startswith("hrv_") and seen_hrv:
            continue
        series = _series_for_metric(metrics, metric_type)
        if metric_type == "sleep_total" and not series:
            series = [
                (row["local_date"], float(row["total_minutes"]))
                for row in sleep_rows
                if row.get("total_minutes") is not None
            ]
        if metric_type == "sleep_total":
            # Optional deep-sleep trend from sleep table.
            deep_series = [
                (row["local_date"], float(row["deep_minutes"]))
                for row in sleep_rows
                if row.get("deep_minutes") is not None
            ]
            if len(deep_series) >= MIN_TREND_COMPARE_POINTS:
                deep_card = _trend_card("sleep_deep", "sleep_deep", deep_series, lang, window_days)
                if deep_card is not None:
                    cards.append(deep_card)
        if len(series) < MIN_TREND_COMPARE_POINTS:
            continue
        if metric_type.startswith("hrv_"):
            seen_hrv = True
        card = _trend_card(metric_type, title_key, series, lang, window_days)
        if card is not None:
            cards.append(card)
    return cards[:12]


def _trend_card(
    metric_type: str,
    title_key: str,
    series: list[tuple[date, float]],
    lang: str,
    window_days: int,
) -> InsightCard | None:
    if len(series) < MIN_TREND_COMPARE_POINTS:
        return None
    recent = [v for _, v in series[-7:]]
    older = [v for _, v in series[:-7]]
    if not recent or not older:
        return None
    delta = median(recent) - median(older)
    return InsightCard(
        insightKey=f"trend_{metric_type}",
        title=_t(lang, f"trend_{title_key}_title"),
        observation=_t(
            lang,
            f"trend_{title_key}_obs",
            days=len(series),
            direction=_direction_word(lang, delta),
        ),
        recommendation=_t(lang, f"trend_{title_key}_rec"),
        confidence=_confidence(len(series), window_days),
        sampleSize=len(series),
        windowDays=window_days,
        supportingFactors=[metric_type],
        limitations=[_t(lang, "limitation_not_causal")],
        whyShown=_t(lang, "why_trend", days=len(series)),
        chart={"metric": metric_type, "points": [{"date": d.isoformat(), "value": v} for d, v in series]},
    )


def _compute_associations(
    env_by_day: dict[date, dict[str, float | None]],
    symptoms_by_day: dict[date, list[dict[str, Any]]],
    metrics: list[dict[str, Any]],
    sleep_rows: list[dict[str, Any]],
    lang: str,
    window_days: int,
) -> list[InsightCard]:
    cards: list[InsightCard] = []
    symptom_days = {d for d, items in symptoms_by_day.items() if items}
    if len(symptom_days) < MIN_ASSOCIATION_SYMPTOM_DAYS:
        return cards

    sleep_by_day = {
        row["local_date"]: float(row["total_minutes"])
        for row in sleep_rows
        if row.get("total_minutes") is not None
    }
    pm_days = {
        d: env.get("pm25")
        for d, env in env_by_day.items()
        if env.get("pm25") is not None
    }
    temp_days = {
        d: env.get("temperature")
        for d, env in env_by_day.items()
        if env.get("temperature") is not None
    }
    aqi_days = {
        d: env.get("aqi")
        for d, env in env_by_day.items()
        if env.get("aqi") is not None
    }

    # Same-day: high PM2.5 + cough-like symptoms
    cough_types = {"cough", "dry_cough", "wet_cough", "wheeze", "airway_irritation"}
    cards.extend(
        _association_card(
            factor_name="pm25",
            factor_days=pm_days,
            high_threshold=35.0,
            symptom_types=cough_types,
            symptoms_by_day=symptoms_by_day,
            lang=lang,
            window_days=window_days,
            key="assoc_pm25_cough",
            title_key="assoc_pm25_cough_title",
            obs_key="assoc_pm25_cough_obs",
            rec_key="assoc_pm25_cough_rec",
        )
    )
    # High temperature + weakness/fatigue
    heat_types = {"fatigue", "weakness", "heat_weakness", "overheating", "heat_intolerance", "intense_thirst"}
    cards.extend(
        _association_card(
            factor_name="temperature",
            factor_days=temp_days,
            high_threshold=30.0,
            symptom_types=heat_types,
            symptoms_by_day=symptoms_by_day,
            lang=lang,
            window_days=window_days,
            key="assoc_heat_fatigue",
            title_key="assoc_heat_fatigue_title",
            obs_key="assoc_heat_fatigue_obs",
            rec_key="assoc_heat_fatigue_rec",
        )
    )
    # Short sleep + higher severity next day / same day
    if sleep_by_day:
        short_sleep_days = {d for d, minutes in sleep_by_day.items() if minutes < 390}
        overlap = []
        for d in short_sleep_days:
            items = symptoms_by_day.get(d, []) + symptoms_by_day.get(d + timedelta(days=1), [])
            severities = [
                int(i["severity"])
                for i in items
                if i.get("severity") is not None
            ]
            if severities and (sum(severities) / len(severities)) >= 3:
                overlap.append(d)
        if len(short_sleep_days) >= MIN_ASSOCIATION_SYMPTOM_DAYS and overlap:
            confidence = _confidence(len(overlap), window_days)
            cards.append(
                InsightCard(
                    insightKey="assoc_short_sleep_symptoms",
                    title=_t(lang, "assoc_short_sleep_title"),
                    observation=_t(
                        lang,
                        "assoc_short_sleep_obs",
                        hit=len(overlap),
                        total=len(short_sleep_days),
                    ),
                    recommendation=_t(lang, "assoc_short_sleep_rec"),
                    confidence=confidence,
                    sampleSize=len(overlap),
                    windowDays=window_days,
                    supportingFactors=["sleep_total", "symptoms"],
                    limitations=[_t(lang, "limitation_not_causal"), _t(lang, "limitation_lag")],
                    whyShown=_t(lang, "why_association", days=len(overlap)),
                )
            )

    # Combined: poor sleep + high AQI → fatigue
    poor_sleep = {d for d, m in sleep_by_day.items() if m < 390}
    high_aqi = {d for d, v in aqi_days.items() if v is not None and v >= 100}
    combo_days = poor_sleep & high_aqi
    fatigue_hit = [
        d
        for d in combo_days
        if any(s.get("symptomType") in {"fatigue", "low_energy", "weakness"} for s in symptoms_by_day.get(d, []))
    ]
    if len(combo_days) >= 3 and fatigue_hit:
        cards.append(
            InsightCard(
                insightKey="assoc_sleep_aqi_fatigue",
                title=_t(lang, "assoc_combo_title"),
                observation=_t(
                    lang,
                    "assoc_combo_obs",
                    hit=len(fatigue_hit),
                    total=len(combo_days),
                ),
                recommendation=_t(lang, "assoc_combo_rec"),
                confidence=_confidence(len(fatigue_hit), window_days),
                sampleSize=len(fatigue_hit),
                windowDays=window_days,
                supportingFactors=["sleep_total", "aqi", "fatigue"],
                limitations=[_t(lang, "limitation_not_causal")],
                whyShown=_t(lang, "why_association", days=len(fatigue_hit)),
            )
        )

    # Baseline deviation for resting HR
    rhr_series = _series_for_metric(metrics, "resting_heart_rate")
    if len(rhr_series) >= MIN_TREND_DAYS:
        values = [v for _, v in rhr_series]
        base = median(values)
        latest = values[-1]
        if latest >= base + 8:
            cards.append(
                InsightCard(
                    insightKey="baseline_rhr_elevated",
                    title=_t(lang, "baseline_rhr_title"),
                    observation=_t(lang, "baseline_rhr_obs"),
                    recommendation=_t(lang, "baseline_rhr_rec"),
                    confidence=_confidence(len(values), window_days),
                    sampleSize=len(values),
                    windowDays=window_days,
                    supportingFactors=["resting_heart_rate"],
                    limitations=[_t(lang, "limitation_not_diagnosis")],
                    whyShown=_t(lang, "why_baseline", days=len(values)),
                )
            )

    humidity_days = {
        d: env.get("humidity")
        for d, env in env_by_day.items()
        if env.get("humidity") is not None
    }
    ozone_days = {
        d: env.get("ozone")
        for d, env in env_by_day.items()
        if env.get("ozone") is not None
    }
    pm10_days = {
        d: env.get("pm10")
        for d, env in env_by_day.items()
        if env.get("pm10") is not None
    }

    allergy_types = {"sneezing", "runny_nose", "nasal_congestion", "itchy_eyes", "watery_eyes"}
    cards.extend(
        _association_card(
            factor_name="aqi",
            factor_days=aqi_days,
            high_threshold=80.0,
            symptom_types=allergy_types,
            symptoms_by_day=symptoms_by_day,
            lang=lang,
            window_days=window_days,
            key="assoc_aqi_allergy",
            title_key="assoc_aqi_allergy_title",
            obs_key="assoc_aqi_allergy_obs",
            rec_key="assoc_aqi_allergy_rec",
        )
    )
    cards.extend(
        _association_card(
            factor_name="pm10",
            factor_days=pm10_days,
            high_threshold=50.0,
            symptom_types=cough_types | allergy_types,
            symptoms_by_day=symptoms_by_day,
            lang=lang,
            window_days=window_days,
            key="assoc_pm10_irritation",
            title_key="assoc_pm10_title",
            obs_key="assoc_pm10_obs",
            rec_key="assoc_pm10_rec",
        )
    )
    headache_types = {"headache", "migraine_like_pain", "pressure_in_head", "light_sensitivity"}
    cards.extend(
        _association_card(
            factor_name="humidity",
            factor_days=humidity_days,
            high_threshold=75.0,
            symptom_types=headache_types,
            symptoms_by_day=symptoms_by_day,
            lang=lang,
            window_days=window_days,
            key="assoc_humidity_headache",
            title_key="assoc_humidity_title",
            obs_key="assoc_humidity_obs",
            rec_key="assoc_humidity_rec",
        )
    )
    breathing_types = {"shortness_of_breath", "chest_tightness", "wheeze", "airway_irritation"}
    cards.extend(
        _association_card(
            factor_name="ozone",
            factor_days=ozone_days,
            high_threshold=100.0,
            symptom_types=breathing_types,
            symptoms_by_day=symptoms_by_day,
            lang=lang,
            window_days=window_days,
            key="assoc_ozone_breathing",
            title_key="assoc_ozone_title",
            obs_key="assoc_ozone_obs",
            rec_key="assoc_ozone_rec",
        )
    )

    # Short sleep → next-day lower HRV (recovery signal)
    hrv_series = _series_for_metric(metrics, "hrv_sdnn") or _series_for_metric(metrics, "hrv_rmssd")
    if sleep_by_day and len(hrv_series) >= MIN_TREND_DAYS:
        hrv_by_day = {d: v for d, v in hrv_series}
        hrv_median = median([v for _, v in hrv_series])
        short_sleep_days = {d for d, minutes in sleep_by_day.items() if minutes < 390}
        low_hrv_hits = [
            d
            for d in short_sleep_days
            if (hrv_by_day.get(d + timedelta(days=1)) is not None and hrv_by_day[d + timedelta(days=1)] < hrv_median * 0.9)
            or (hrv_by_day.get(d) is not None and hrv_by_day[d] < hrv_median * 0.9)
        ]
        if len(short_sleep_days) >= MIN_ASSOCIATION_SYMPTOM_DAYS and len(low_hrv_hits) >= 3:
            cards.append(
                InsightCard(
                    insightKey="assoc_short_sleep_hrv",
                    title=_t(lang, "assoc_sleep_hrv_title"),
                    observation=_t(
                        lang,
                        "assoc_sleep_hrv_obs",
                        hit=len(low_hrv_hits),
                        total=len(short_sleep_days),
                    ),
                    recommendation=_t(lang, "assoc_sleep_hrv_rec"),
                    confidence=_confidence(len(low_hrv_hits), window_days),
                    sampleSize=len(low_hrv_hits),
                    windowDays=window_days,
                    supportingFactors=["sleep_total", "hrv"],
                    limitations=[_t(lang, "limitation_not_causal"), _t(lang, "limitation_lag")],
                    whyShown=_t(lang, "why_association", days=len(low_hrv_hits)),
                )
            )

    # Higher workout load on hot / high-AQI days → fatigue
    workout_series = _series_for_metric(metrics, "workout_duration") or _series_for_metric(
        metrics, "exercise_minutes"
    )
    if workout_series:
        workout_by_day = {d: v for d, v in workout_series}
        hard_days = {
            d
            for d, minutes in workout_by_day.items()
            if minutes >= 45
            and (
                (temp_days.get(d) is not None and temp_days[d] >= 28)
                or (aqi_days.get(d) is not None and aqi_days[d] >= 100)
            )
        }
        fatigue_on_hard = [
            d
            for d in hard_days
            if any(
                s.get("symptomType") in {"fatigue", "weakness", "low_energy", "overheating"}
                for s in symptoms_by_day.get(d, [])
            )
        ]
        if len(hard_days) >= 3 and fatigue_on_hard:
            cards.append(
                InsightCard(
                    insightKey="assoc_workout_env_fatigue",
                    title=_t(lang, "assoc_workout_env_title"),
                    observation=_t(
                        lang,
                        "assoc_workout_env_obs",
                        hit=len(fatigue_on_hard),
                        total=len(hard_days),
                    ),
                    recommendation=_t(lang, "assoc_workout_env_rec"),
                    confidence=_confidence(len(fatigue_on_hard), window_days),
                    sampleSize=len(fatigue_on_hard),
                    windowDays=window_days,
                    supportingFactors=["workout_duration", "temperature", "aqi"],
                    limitations=[_t(lang, "limitation_not_causal")],
                    whyShown=_t(lang, "why_association", days=len(fatigue_on_hard)),
                )
            )

    # Higher steps days with fewer symptoms — positive pattern
    steps_series = _series_for_metric(metrics, "steps")
    if len(steps_series) >= MIN_TREND_DAYS and symptom_days:
        steps_vals = [v for _, v in steps_series]
        steps_cut = median(steps_vals)
        active_days = {d for d, v in steps_series if v >= max(steps_cut, 6000)}
        calm_active = [
            d
            for d in active_days
            if max((int(s.get("severity") or 0) for s in symptoms_by_day.get(d, [])), default=0) <= 2
        ]
        if len(active_days) >= MIN_ASSOCIATION_SYMPTOM_DAYS and len(calm_active) >= 3:
            cards.append(
                InsightCard(
                    insightKey="assoc_active_better_feel",
                    title=_t(lang, "assoc_steps_feel_title"),
                    observation=_t(
                        lang,
                        "assoc_steps_feel_obs",
                        hit=len(calm_active),
                        total=len(active_days),
                    ),
                    recommendation=_t(lang, "assoc_steps_feel_rec"),
                    confidence=_confidence(len(calm_active), window_days),
                    sampleSize=len(calm_active),
                    windowDays=window_days,
                    supportingFactors=["steps", "symptoms"],
                    limitations=[_t(lang, "limitation_not_causal")],
                    whyShown=_t(lang, "why_association", days=len(calm_active)),
                )
            )

    return cards[:16]


def _association_card(
    *,
    factor_name: str,
    factor_days: dict[date, float | None],
    high_threshold: float,
    symptom_types: set[str],
    symptoms_by_day: dict[date, list[dict[str, Any]]],
    lang: str,
    window_days: int,
    key: str,
    title_key: str,
    obs_key: str,
    rec_key: str,
) -> list[InsightCard]:
    high_days = {d for d, v in factor_days.items() if v is not None and v >= high_threshold}
    if len(high_days) < MIN_ASSOCIATION_SYMPTOM_DAYS:
        return []
    hits = [
        d
        for d in high_days
        if any(s.get("symptomType") in symptom_types for s in symptoms_by_day.get(d, []))
    ]
    if len(hits) < 3:
        return []
    return [
        InsightCard(
            insightKey=key,
            title=_t(lang, title_key),
            observation=_t(lang, obs_key, hit=len(hits), total=len(high_days)),
            recommendation=_t(lang, rec_key),
            confidence=_confidence(len(hits), window_days),
            sampleSize=len(hits),
            windowDays=window_days,
            supportingFactors=[factor_name, "symptoms"],
            limitations=[_t(lang, "limitation_not_causal")],
            whyShown=_t(lang, "why_association", days=len(hits)),
        )
    ]


def _insufficient_data_cards(
    *,
    metrics: list[dict[str, Any]],
    sleep_rows: list[dict[str, Any]],
    symptoms_by_day: dict[date, list[dict[str, Any]]],
    lang: str,
    window_days: int,
) -> list[dict[str, Any]]:
    cards = []
    symptom_days = len([d for d, items in symptoms_by_day.items() if items])
    if symptom_days < MIN_ASSOCIATION_SYMPTOM_DAYS:
        cards.append(
            {
                "key": "need_symptoms",
                "message": _t(
                    lang,
                    "need_symptoms",
                    have=symptom_days,
                    need=MIN_ASSOCIATION_SYMPTOM_DAYS,
                ),
                "have": symptom_days,
                "need": MIN_ASSOCIATION_SYMPTOM_DAYS,
                "action": "log_symptoms",
            }
        )
    sleep_days = len([r for r in sleep_rows if r.get("total_minutes") is not None])
    if sleep_days < MIN_TREND_DAYS:
        cards.append(
            {
                "key": "need_sleep",
                "message": _t(lang, "need_sleep", have=sleep_days, need=MIN_TREND_DAYS),
                "have": sleep_days,
                "need": MIN_TREND_DAYS,
                "action": "connect_sleep",
            }
        )
    metric_types = {m["metric_type"] for m in metrics}
    if "resting_heart_rate" not in metric_types and "heart_rate" not in metric_types:
        cards.append(
            {
                "key": "need_heart",
                "message": _t(lang, "need_heart"),
                "have": 0,
                "need": MIN_TREND_DAYS,
                "action": "connect_heart",
            }
        )
    if not cards and window_days:
        cards.append(
            {
                "key": "building",
                "message": _t(lang, "building_patterns"),
                "have": symptom_days,
                "need": MIN_STRONGER_DAYS,
                "action": "keep_logging",
            }
        )
    return cards


def _health_data_status(
    user_id: str,
    metrics: list[dict[str, Any]],
    sleep_rows: list[dict[str, Any]],
) -> dict[str, Any]:
    sync = health_sync_repository.get_sync_state(user_id)
    categories = {
        "activity": any(m["metric_type"] in {"steps", "active_energy", "exercise_minutes"} for m in metrics),
        "heart": any(m["metric_type"].startswith("heart") or m["metric_type"].startswith("hrv") or m["metric_type"] == "resting_heart_rate" for m in metrics),
        "sleep": bool(sleep_rows) or any(m["metric_type"].startswith("sleep_") for m in metrics),
        "respiratory": any(m["metric_type"] in {"respiratory_rate", "oxygen_saturation"} for m in metrics),
        "temperature": any(m["metric_type"] in {"body_temperature", "wrist_temperature"} for m in metrics),
        "workouts": any(m["metric_type"].startswith("workout_") for m in metrics),
    }
    return {
        "lastSuccessAt": sync.get("last_success_at").isoformat() if sync and sync.get("last_success_at") else None,
        "syncStatus": sync.get("sync_status") if sync else None,
        "categoriesConnected": categories,
        "metricDays": len({m["local_date"] for m in metrics}),
        "sleepDays": len(sleep_rows),
    }


def _load_environment_by_day(profile_id: str, start: date, end: date) -> dict[date, dict[str, float | None]]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    DATE(es.timestamp_utc) AS day_key,
                    AVG(es.pm25) AS pm25,
                    AVG(es.pm10) AS pm10,
                    AVG(es.ozone) AS ozone,
                    AVG(es.temperature_c) AS temperature,
                    AVG(es.humidity_percent) AS humidity,
                    AVG(es.aqi) AS aqi
                FROM environment_snapshots es
                JOIN risk_assessments ra ON ra.environmental_snapshot_id = es.id
                WHERE ra.user_profile_id = %s
                  AND DATE(es.timestamp_utc) BETWEEN %s AND %s
                GROUP BY DATE(es.timestamp_utc)
                """,
                (profile_id, start, end),
            )
            rows = cur.fetchall()
    result: dict[date, dict[str, float | None]] = {}
    for row in rows:
        day = row["day_key"]
        result[day] = {
            "pm25": _nullable_float(row.get("pm25")),
            "pm10": _nullable_float(row.get("pm10")),
            "ozone": _nullable_float(row.get("ozone")),
            "temperature": _nullable_float(row.get("temperature")),
            "humidity": _nullable_float(row.get("humidity")),
            "aqi": _nullable_float(row.get("aqi")),
        }
    return result


def _load_symptoms_by_day(profile_id: str, start: date, end: date) -> dict[date, list[dict[str, Any]]]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    COALESCE(DATE(logged_at), DATE(timestamp_utc)) AS day_key,
                    symptom_type,
                    COALESCE(severity, intensity) AS severity,
                    category,
                    note
                FROM symptom_logs
                WHERE profile_id = %s
                  AND COALESCE(logged_at, timestamp_utc) >= %s
                  AND COALESCE(logged_at, timestamp_utc) < %s + INTERVAL '1 day'
                  AND deleted_at IS NULL
                """,
                (profile_id, start, end),
            )
            rows = cur.fetchall()
    # Also expand legacy boolean rows
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    COALESCE(DATE(logged_at), DATE(timestamp_utc)) AS day_key,
                    cough, wheeze, headache, fatigue, sleep_quality
                FROM symptom_logs
                WHERE profile_id = %s
                  AND COALESCE(logged_at, timestamp_utc) >= %s
                  AND COALESCE(logged_at, timestamp_utc) < %s + INTERVAL '1 day'
                  AND symptom_type IS NULL
                  AND deleted_at IS NULL
                """,
                (profile_id, start, end),
            )
            legacy = cur.fetchall()

    by_day: dict[date, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if not row.get("symptom_type"):
            continue
        by_day[row["day_key"]].append(
            {
                "symptomType": row["symptom_type"],
                "severity": int(row["severity"]) if row.get("severity") is not None else None,
                "category": row.get("category"),
                "note": row.get("note"),
            }
        )
    for row in legacy:
        day = row["day_key"]
        for field, stype in (
            ("cough", "cough"),
            ("wheeze", "wheeze"),
            ("headache", "headache"),
            ("fatigue", "fatigue"),
        ):
            if row.get(field):
                by_day[day].append({"symptomType": stype, "severity": 3, "category": None, "note": None})
    return by_day


def _load_risk_by_day(profile_id: str, start: date, end: date) -> dict[date, dict[str, Any]]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT DATE(created_at) AS day_key,
                       MAX(overall_risk) AS level
                FROM risk_assessments
                WHERE user_profile_id = %s
                  AND DATE(created_at) BETWEEN %s AND %s
                GROUP BY DATE(created_at)
                """,
                (profile_id, start, end),
            )
            rows = cur.fetchall()
    return {
        row["day_key"]: {"score": None, "level": row.get("level")}
        for row in rows
    }


def _series_for_metric(metrics: list[dict[str, Any]], metric_type: str) -> list[tuple[date, float]]:
    series = []
    for row in metrics:
        if row["metric_type"] != metric_type:
            continue
        value = _row_primary_value(row)
        if value is None:
            continue
        series.append((row["local_date"], value))
    series.sort(key=lambda item: item[0])
    return series


def _row_primary_value(row: dict[str, Any]) -> float | None:
    for key in ("value_avg", "value_total", "value_latest"):
        if row.get(key) is not None:
            return float(row[key])
    return None


def _metric_value(rows: list[dict[str, Any]], metric_type: str) -> float | None:
    for row in rows:
        if row["metric_type"] == metric_type:
            return _row_primary_value(row)
    return None


def _nullable_float(value: Any) -> float | None:
    if value is None:
        return None
    return float(value)


def _confidence(sample_size: int, window_days: int) -> str:
    if sample_size < MIN_ASSOCIATION_SYMPTOM_DAYS:
        return "insufficient"
    if sample_size < MIN_TREND_DAYS:
        return "preliminary"
    if sample_size < MIN_STRONGER_DAYS:
        return "moderate"
    if sample_size >= MIN_STRONGER_DAYS and window_days >= 30:
        return "stronger"
    return "moderate"


def _direction_word(lang: str, delta: float) -> str:
    if abs(delta) < 1e-6:
        return {"ru": "без выраженного изменения", "en": "little change"}.get(lang, "little change")
    if delta > 0:
        return {"ru": "выше", "en": "higher"}.get(lang, "higher")
    return {"ru": "ниже", "en": "lower"}.get(lang, "lower")


_STRINGS: dict[str, dict[str, str]] = {
    "ru": {
        "trend_steps_title": "Активность за период",
        "trend_steps_obs": "За {days} дн. шаги в среднем {direction} вашего более раннего уровня.",
        "trend_steps_rec": "Учитывайте самочувствие и качество воздуха при планировании нагрузки.",
        "trend_resting_hr_title": "Пульс в покое",
        "trend_resting_hr_obs": "За {days} дн. пульс в покое {direction} обычного диапазона.",
        "trend_resting_hr_rec": "При необычных ощущениях снизьте интенсивность и при необходимости обратитесь к специалисту.",
        "trend_hrv_title": "Вариабельность пульса",
        "trend_hrv_obs": "За {days} дн. показатель HRV {direction} вашей недавней линии.",
        "trend_hrv_rec": "Это сигнал восстановления, а не диагноз. Учитывайте сон и нагрузку.",
        "trend_sleep_title": "Сон",
        "trend_sleep_obs": "За {days} дн. продолжительность сна {direction} вашей обычной.",
        "trend_sleep_rec": "Рассмотрите более спокойный вечерний режим и более лёгкую нагрузку на следующий день.",
        "trend_distance_title": "Дистанция",
        "trend_distance_obs": "За {days} дн. пройденная дистанция {direction} вашей более ранней линии.",
        "trend_distance_rec": "Учитывайте качество воздуха, если увеличиваете прогулки.",
        "trend_active_energy_title": "Активная энергия",
        "trend_active_energy_obs": "За {days} дн. расход активной энергии {direction} обычного уровня.",
        "trend_active_energy_rec": "Соизмеряйте нагрузку с самочувствием и жарой.",
        "trend_exercise_title": "Минуты упражнений",
        "trend_exercise_obs": "За {days} дн. минуты упражнений {direction} вашей недавней линии.",
        "trend_exercise_rec": "В дни с высоким риском среды выбирайте более щадящий план.",
        "trend_workout_title": "Тренировки",
        "trend_workout_obs": "За {days} дн. длительность тренировок {direction} обычного уровня.",
        "trend_workout_rec": "После интенсивных дней дайте себе больше восстановления.",
        "trend_spo2_title": "Кислород в крови",
        "trend_spo2_obs": "За {days} дн. показатель SpO₂ {direction} вашей недавней линии.",
        "trend_spo2_rec": "Это wellness-сигнал. При необычных ощущениях снизьте нагрузку.",
        "trend_resp_title": "Частота дыхания",
        "trend_resp_obs": "За {days} дн. частота дыхания {direction} обычного диапазона.",
        "trend_resp_rec": "Учитывайте воздух и нагрузку; это не диагноз.",
        "trend_sleep_deep_title": "Глубокий сон",
        "trend_sleep_deep_obs": "За {days} дн. глубокий сон {direction} вашей обычной.",
        "trend_sleep_deep_rec": "Более спокойный вечер может поддержать восстановление.",
        "assoc_pm25_cough_title": "Частицы PM2.5 и дыхание",
        "assoc_pm25_cough_obs": "В {hit} из {total} дней с повышенным PM2.5 чаще отмечались симптомы дыхания.",
        "assoc_pm25_cough_rec": "В дни с высоким PM2.5 по возможности сократите интенсивную активность на улице.",
        "assoc_heat_fatigue_title": "Жара и усталость",
        "assoc_heat_fatigue_obs": "В {hit} из {total} жарких дней чаще отмечались усталость или слабость.",
        "assoc_heat_fatigue_rec": "Пейте воду, выбирайте тень и более прохладные окна для прогулок.",
        "assoc_short_sleep_title": "Короткий сон и самочувствие",
        "assoc_short_sleep_obs": "В {hit} из {total} дней с коротким сном тяжесть симптомов была выше.",
        "assoc_short_sleep_rec": "После короткой ночи рассмотрите более лёгкую нагрузку.",
        "assoc_combo_title": "Сон и качество воздуха",
        "assoc_combo_obs": "В {hit} из {total} дней с коротким сном и высоким AQI отмечалась усталость.",
        "assoc_combo_rec": "В такие дни выбирайте более щадящий план активности.",
        "baseline_rhr_title": "Пульс в покое выше обычного",
        "baseline_rhr_obs": "Наблюдается отклонение пульса в покое вверх от вашей персональной базы.",
        "baseline_rhr_rec": "Учитывайте самочувствие и снизьте интенсивность нагрузки.",
        "assoc_aqi_allergy_title": "Качество воздуха и аллергия",
        "assoc_aqi_allergy_obs": "В {hit} из {total} дней с повышенным AQI чаще отмечались аллергические симптомы.",
        "assoc_aqi_allergy_rec": "В такие дни сократите время на улице и проветрите помещение вне пика загрязнения.",
        "assoc_pm10_title": "PM10 и раздражение",
        "assoc_pm10_obs": "В {hit} из {total} дней с повышенным PM10 чаще отмечались симптомы раздражения.",
        "assoc_pm10_rec": "При высоком PM10 выбирайте более короткие и спокойные выходы.",
        "assoc_humidity_title": "Влажность и голова",
        "assoc_humidity_obs": "В {hit} из {total} дней с высокой влажностью чаще отмечалась головная боль.",
        "assoc_humidity_rec": "Пейте воду и избегайте духоты в помещении.",
        "assoc_ozone_title": "Озон и дыхание",
        "assoc_ozone_obs": "В {hit} из {total} дней с повышенным озоном чаще отмечались дыхательные симптомы.",
        "assoc_ozone_rec": "В такие дни предпочитайте утренние или вечерние окна активности.",
        "assoc_sleep_hrv_title": "Короткий сон и восстановление",
        "assoc_sleep_hrv_obs": "В {hit} из {total} дней с коротким сном HRV был ниже вашей обычной линии.",
        "assoc_sleep_hrv_rec": "После короткой ночи снизьте интенсивность и дайте себе восстановиться.",
        "assoc_workout_env_title": "Тренировки в тяжёлой среде",
        "assoc_workout_env_obs": "В {hit} из {total} дней с высокой нагрузкой при жаре или высоком AQI отмечалась усталость.",
        "assoc_workout_env_rec": "В жаркие или загрязнённые дни сократите длительность интенсивных тренировок.",
        "assoc_steps_feel_title": "Активные дни и самочувствие",
        "assoc_steps_feel_obs": "В {hit} из {total} более активных дней симптомы были мягче.",
        "assoc_steps_feel_rec": "Умеренная активность в безопасные окна часто поддерживает самочувствие.",
        "limitation_not_causal": "Это наблюдение связи, а не доказанная причина.",
        "limitation_lag": "Учтены окна того же и следующего дня.",
        "limitation_not_diagnosis": "HiAir не ставит медицинских диагнозов.",
        "why_trend": "Показано, потому что есть данные за {days} дн.",
        "why_association": "Показано по {days} совпадающим дням наблюдений.",
        "why_baseline": "Персональная база построена по {days} дн.",
        "need_symptoms": "Есть данные за {have} из {need} необходимых дней с симптомами.",
        "need_sleep": "Есть данные сна за {have} из {need} необходимых дней.",
        "need_heart": "Подключите данные сердца, чтобы увидеть тренды восстановления.",
        "building_patterns": "Продолжайте отмечать симптомы — более уверенные связи появятся с накоплением данных.",
        "insufficient_consent": "Подключите Apple Health / Health Connect, чтобы открыть персональные инсайты.",
    },
    "en": {
        "trend_steps_title": "Activity trend",
        "trend_steps_obs": "Over {days} days, steps were {direction} than your earlier level.",
        "trend_steps_rec": "Consider how you feel and air quality when planning activity.",
        "trend_resting_hr_title": "Resting heart rate",
        "trend_resting_hr_obs": "Over {days} days, resting heart rate was {direction} than your usual range.",
        "trend_resting_hr_rec": "If you feel unusual, ease intensity and seek professional care if needed.",
        "trend_hrv_title": "Heart-rate variability",
        "trend_hrv_obs": "Over {days} days, HRV was {direction} than your recent baseline.",
        "trend_hrv_rec": "This is a recovery signal, not a diagnosis. Consider sleep and load.",
        "trend_sleep_title": "Sleep",
        "trend_sleep_obs": "Over {days} days, sleep duration was {direction} than usual.",
        "trend_sleep_rec": "Consider a calmer evening routine and lighter activity the next day.",
        "trend_distance_title": "Distance",
        "trend_distance_obs": "Over {days} days, walking distance was {direction} than your earlier level.",
        "trend_distance_rec": "Consider air quality when increasing outdoor walking.",
        "trend_active_energy_title": "Active energy",
        "trend_active_energy_obs": "Over {days} days, active energy was {direction} than usual.",
        "trend_active_energy_rec": "Match load to how you feel and heat conditions.",
        "trend_exercise_title": "Exercise minutes",
        "trend_exercise_obs": "Over {days} days, exercise minutes were {direction} than your recent baseline.",
        "trend_exercise_rec": "On higher environmental-risk days, prefer a gentler plan.",
        "trend_workout_title": "Workouts",
        "trend_workout_obs": "Over {days} days, workout duration was {direction} than usual.",
        "trend_workout_rec": "After intense days, protect recovery time.",
        "trend_spo2_title": "Blood oxygen",
        "trend_spo2_obs": "Over {days} days, SpO₂ was {direction} than your recent baseline.",
        "trend_spo2_rec": "This is a wellness signal. Ease intensity if you feel unusual.",
        "trend_resp_title": "Respiratory rate",
        "trend_resp_obs": "Over {days} days, breathing rate was {direction} than your usual range.",
        "trend_resp_rec": "Consider air and load; this is not a diagnosis.",
        "trend_sleep_deep_title": "Deep sleep",
        "trend_sleep_deep_obs": "Over {days} days, deep sleep was {direction} than usual.",
        "trend_sleep_deep_rec": "A calmer evening may support recovery.",
        "assoc_pm25_cough_title": "PM2.5 and breathing",
        "assoc_pm25_cough_obs": "On {hit} of {total} higher-PM2.5 days, breathing symptoms were noted more often.",
        "assoc_pm25_cough_rec": "On high-PM2.5 days, consider reducing intense outdoor activity.",
        "assoc_heat_fatigue_title": "Heat and fatigue",
        "assoc_heat_fatigue_obs": "On {hit} of {total} hotter days, fatigue or weakness was noted more often.",
        "assoc_heat_fatigue_rec": "Hydrate, seek shade, and prefer cooler outdoor windows.",
        "assoc_short_sleep_title": "Short sleep and how you feel",
        "assoc_short_sleep_obs": "On {hit} of {total} short-sleep days, symptom severity was higher.",
        "assoc_short_sleep_rec": "After a short night, consider lighter activity.",
        "assoc_combo_title": "Sleep and air quality",
        "assoc_combo_obs": "On {hit} of {total} days with short sleep and higher AQI, fatigue was noted.",
        "assoc_combo_rec": "On those days, choose a gentler activity plan.",
        "baseline_rhr_title": "Resting pulse above your usual",
        "baseline_rhr_obs": "Resting heart rate appears above your personal baseline.",
        "baseline_rhr_rec": "Consider how you feel and reduce intensity.",
        "assoc_aqi_allergy_title": "Air quality and allergy-like symptoms",
        "assoc_aqi_allergy_obs": "On {hit} of {total} higher-AQI days, allergy-like symptoms were noted more often.",
        "assoc_aqi_allergy_rec": "On those days, shorten outdoor time and ventilate outside peak pollution.",
        "assoc_pm10_title": "PM10 and irritation",
        "assoc_pm10_obs": "On {hit} of {total} higher-PM10 days, irritation symptoms were noted more often.",
        "assoc_pm10_rec": "On high-PM10 days, prefer shorter and calmer outdoor periods.",
        "assoc_humidity_title": "Humidity and headaches",
        "assoc_humidity_obs": "On {hit} of {total} higher-humidity days, headache was noted more often.",
        "assoc_humidity_rec": "Hydrate and avoid stuffy indoor air.",
        "assoc_ozone_title": "Ozone and breathing",
        "assoc_ozone_obs": "On {hit} of {total} higher-ozone days, breathing symptoms were noted more often.",
        "assoc_ozone_rec": "Prefer morning or evening activity windows on those days.",
        "assoc_sleep_hrv_title": "Short sleep and recovery",
        "assoc_sleep_hrv_obs": "On {hit} of {total} short-sleep days, HRV was below your usual line.",
        "assoc_sleep_hrv_rec": "After a short night, ease intensity and protect recovery.",
        "assoc_workout_env_title": "Harder workouts in tough conditions",
        "assoc_workout_env_obs": "On {hit} of {total} higher-load days in heat or high AQI, fatigue was noted.",
        "assoc_workout_env_rec": "On hot or polluted days, shorten intense sessions.",
        "assoc_steps_feel_title": "Active days and how you feel",
        "assoc_steps_feel_obs": "On {hit} of {total} more active days, symptoms were milder.",
        "assoc_steps_feel_rec": "Moderate activity in safer windows often supports how you feel.",
        "limitation_not_causal": "This is an observed association, not proven causation.",
        "limitation_lag": "Same-day and next-day windows were considered.",
        "limitation_not_diagnosis": "HiAir does not provide medical diagnoses.",
        "why_trend": "Shown because {days} days of data are available.",
        "why_association": "Shown from {days} matching observation days.",
        "why_baseline": "Personal baseline uses {days} days.",
        "need_symptoms": "Symptom data available for {have} of {need} needed days.",
        "need_sleep": "Sleep data available for {have} of {need} needed days.",
        "need_heart": "Connect heart data to see recovery trends.",
        "building_patterns": "Keep logging symptoms — clearer patterns need more days.",
        "insufficient_consent": "Connect Apple Health / Health Connect to unlock personal insights.",
    },
}


def _t(lang: str, key: str, **kwargs: Any) -> str:
    table = _STRINGS.get(lang) or _STRINGS["en"]
    template = table.get(key) or _STRINGS["en"].get(key) or key
    try:
        return template.format(**kwargs)
    except Exception:
        return template
