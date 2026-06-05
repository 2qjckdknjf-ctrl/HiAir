from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

from psycopg.errors import UndefinedTable

from app.models.wearable import PersonalLoadSummary, WearableTodayResponse, WearableSource
from app.services.personal_load_engine import PersonalLoadInput, compute_personal_load_score
import app.services.wearable_repository as wearable_repository


def build_personal_load_input(user_id: str, environment=None) -> PersonalLoadInput:
    try:
        consent = wearable_repository.get_active_consent(user_id)
    except UndefinedTable:
        return PersonalLoadInput(consent_active=False)
    if consent is None:
        return PersonalLoadInput(consent_active=False)

    source = consent.source
    today = date.today()
    try:
        daily = wearable_repository.get_daily_summary(user_id, today, source=source)
        now = datetime.now(tz=UTC)
        steps_last_hour = wearable_repository.sum_steps_since(user_id, now - timedelta(hours=1), source=source)
        steps_last_3h = wearable_repository.sum_steps_since(user_id, now - timedelta(hours=3), source=source)
        baseline_7d = wearable_repository.resting_hr_baseline(user_id, 7)
        baseline_30d = wearable_repository.resting_hr_baseline(user_id, 30)
    except UndefinedTable:
        return PersonalLoadInput(consent_active=False)

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
        consent_active=True,
        **env_kwargs,
    )


def build_today_response(user_id: str) -> WearableTodayResponse:
    consent = wearable_repository.get_latest_consent(user_id)
    today = date.today()
    daily = None
    source = consent.source if consent else None
    if source is not None:
        daily = wearable_repository.get_daily_summary(user_id, today, source=source)

    now = datetime.now(tz=UTC)
    steps_last_hour = None
    steps_last_3h = None
    baseline_7d = None
    baseline_30d = None
    if consent and consent.isActive and source is not None:
        steps_last_hour = wearable_repository.sum_steps_since(user_id, now - timedelta(hours=1), source=source)
        steps_last_3h = wearable_repository.sum_steps_since(user_id, now - timedelta(hours=3), source=source)
        baseline_7d = wearable_repository.resting_hr_baseline(user_id, 7)
        baseline_30d = wearable_repository.resting_hr_baseline(user_id, 30)

    load_input = build_personal_load_input(user_id)
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
