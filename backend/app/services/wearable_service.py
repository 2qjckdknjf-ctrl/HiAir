from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

from psycopg.errors import UndefinedTable

from app.models.wearable import PersonalLoadSummary, WearableTodayResponse
from app.services.personal_load_engine import PersonalLoadInput, compute_personal_load_score
import app.services.health_sync_repository as health_sync_repository
import app.services.wearable_repository as wearable_repository


def _metric_primary(rows: list[dict], metric_type: str) -> float | None:
    for row in rows:
        if row.get("metric_type") != metric_type:
            continue
        for key in ("value_avg", "value_total", "value_latest"):
            raw = row.get(key)
            if raw is not None:
                return float(raw)
    return None


def build_personal_load_input(user_id: str, environment=None, *, _core: dict | None = None) -> PersonalLoadInput:
    try:
        consent = wearable_repository.get_active_consent(user_id)
    except UndefinedTable:
        return PersonalLoadInput(consent_active=False)
    if consent is None:
        return PersonalLoadInput(consent_active=False)

    source = consent.source
    today = date.today()
    sleep_minutes: int | None = None
    sleep_minutes_baseline_7d: float | None = None
    hrv_ms: float | None = None
    hrv_baseline_7d: float | None = None
    exercise_minutes: float | None = None
    try:
        core = _core if (_core is not None and _core.get("source") == source
                         and _core.get("user_id") == user_id and _core.get("local_date") == today
                         ) else wearable_repository.get_personal_load_core(user_id, today, source)
        daily = core["daily"]
        steps_last_hour = core["steps_hour"]
        steps_last_3h = core["steps_3h"]
        baseline_7d = core["hr_7d"]
        baseline_30d = core["hr_30d"]
    except UndefinedTable:
        return PersonalLoadInput(consent_active=False)

    # Health Intelligence tables were introduced in stages. Treat each optional
    # signal independently so one unavailable table (for example sleep history)
    # cannot erase valid HRV/exercise data that was already synchronized.
    try:
        today_metrics = health_sync_repository.list_metrics_for_date(user_id, today)
    except UndefinedTable:
        today_metrics = []

    try:
        sleep_row = health_sync_repository.get_sleep_for_date(user_id, today)
        if sleep_row and sleep_row.get("total_minutes") is not None:
            sleep_minutes = int(sleep_row["total_minutes"])
    except UndefinedTable:
        sleep_row = None

    try:
        sleep_window = health_sync_repository.get_sleep_window(
            user_id,
            today - timedelta(days=6),
            today - timedelta(days=1),
        )
        sleep_totals = [
            float(row["total_minutes"])
            for row in sleep_window
            if row.get("total_minutes") is not None
        ]
        # Require ≥5 prior nights — same honesty bar as adaptation baselines.
        if len(sleep_totals) >= 5:
            sleep_minutes_baseline_7d = sum(sleep_totals) / len(sleep_totals)
    except UndefinedTable:
        pass

    # Never compare SDNN against RMSSD — lock method to today's available series.
    hrv_metric = None
    if _metric_primary(today_metrics, "hrv_sdnn") is not None:
        hrv_metric = "hrv_sdnn"
    elif _metric_primary(today_metrics, "hrv_rmssd") is not None:
        hrv_metric = "hrv_rmssd"
    if hrv_metric is not None:
        hrv_ms = _metric_primary(today_metrics, hrv_metric)
        try:
            hrv_baseline_7d = health_sync_repository.metric_baseline(user_id, hrv_metric, 7)
        except UndefinedTable:
            hrv_baseline_7d = None

    exercise_minutes = _metric_primary(today_metrics, "exercise_minutes") or _metric_primary(
        today_metrics, "workout_duration"
    )

    env_kwargs = {}
    if environment is not None:
        env_kwargs = {
            "heat_index": environment.feels_like,
            "temperature": environment.temperature,
            "humidity": environment.humidity,
            "aqi": environment.aqi,
            "ozone": environment.ozone,
            "pm25": environment.pm25,
        }

    return PersonalLoadInput(
        steps_today=daily.stepsTotal if daily else None,
        steps_last_hour=steps_last_hour or None,
        steps_last_3_hours=steps_last_3h or None,
        heart_rate_avg=daily.heartRateAvg if daily else None,
        heart_rate_max=daily.heartRateMax if daily else None,
        resting_heart_rate=daily.restingHeartRateAvg if daily else None,
        resting_heart_rate_baseline_7d=baseline_7d,
        resting_heart_rate_baseline_30d=baseline_30d,
        sleep_minutes=sleep_minutes,
        sleep_minutes_baseline_7d=sleep_minutes_baseline_7d,
        hrv_ms=hrv_ms,
        hrv_baseline_7d=hrv_baseline_7d,
        exercise_minutes=exercise_minutes,
        consent_active=True,
        **env_kwargs,
    )


def build_today_response(user_id: str) -> WearableTodayResponse:
    consent = wearable_repository.get_latest_consent(user_id)
    today = date.today()
    source = consent.source if consent else None
    core = None
    daily = None
    steps_last_hour = steps_last_3h = baseline_7d = baseline_30d = None
    if consent and consent.isActive and source is not None:
        core = wearable_repository.get_personal_load_core(user_id, today, source)
        daily = core["daily"]
        steps_last_hour = core["steps_hour"]
        steps_last_3h = core["steps_3h"]
        baseline_7d = core["hr_7d"]
        baseline_30d = core["hr_30d"]
    elif source is not None:
        daily = wearable_repository.get_daily_summary(user_id, today, source=source)

    # Still recheck active consent; reuse only this request's matching source.
    load_input = build_personal_load_input(user_id, _core=core)
    load_result = compute_personal_load_score(load_input)
    personal_load = PersonalLoadSummary(
        score=load_result.score,
        level=load_result.level,
        explanations=load_result.explanations,
        reasonCodes=load_result.reason_codes,
    )

    return WearableTodayResponse(
        consent=consent,
        dailySummary=daily,
        stepsLastHour=steps_last_hour,
        stepsLast3Hours=steps_last_3h,
        restingHeartRateBaseline7d=baseline_7d,
        restingHeartRateBaseline30d=baseline_30d,
        personalLoad=personal_load,
    )
