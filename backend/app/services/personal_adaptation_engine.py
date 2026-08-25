"""HiAir 1.6 Personal Adaptation Engine.

Wellness-only personal baselines from user-supplied wearable aggregates.
Never invents HRV, resting HR, or sleep. Protected-day counts use structured
events only — no inferred causation.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import UTC, date, datetime, timedelta
from enum import Enum
from statistics import median

from app.models.personal_adaptation import (
    BaselineWindow,
    PersonalBaseline,
    PersonalBaselineMetric,
    PersonalAdaptationSnapshot,
    ProtectedDaysSummary,
)

MIN_BASELINE_SAMPLES = 5

WINDOW_DAYS: dict[BaselineWindow, int] = {
    BaselineWindow.D7: 7,
    BaselineWindow.D30: 30,
}

FORBIDDEN_REASON_FRAGMENTS = (
    "diagnos",
    "disease",
    "disorder",
    "emergency",
    "heart attack",
    "arrhythm",
    "тахикард",
    "диагност",
    "болезн",
    "лечени",
    "treatment effect",
    "caused by",
    "because you",
)


class ProtectedDayEventType(str, Enum):
    HIGH_RISK_PERIOD_AVOIDED = "high_risk_period_avoided"
    WORKOUT_MOVED = "workout_moved"
    VENTILATION_WINDOW_USED = "ventilation_window_used"
    POOR_AIR_EXPOSURE_REDUCED = "poor_air_exposure_reduced"


@dataclass
class DailyMetricSample:
    local_date: date
    value: float


@dataclass
class BaselineMetricSeries:
    metric: PersonalBaselineMetric
    samples: list[DailyMetricSample] = field(default_factory=list)


@dataclass
class BaselineInputs:
    series: list[BaselineMetricSeries] = field(default_factory=list)
    reference_date: date | None = None


@dataclass
class ProtectedDayEvent:
    event_type: ProtectedDayEventType
    event_date: date | None = None


def _sanitize_reason_codes(codes: list[str]) -> list[str]:
    clean: list[str] = []
    for code in codes:
        lower = code.lower().replace("_", " ")
        if any(fragment in lower for fragment in FORBIDDEN_REASON_FRAGMENTS):
            continue
        clean.append(code)
    return clean


def _metric_value_from_row(row: dict) -> float | None:
    for key in ("value_avg", "value_total", "value_latest"):
        raw = row.get(key)
        if raw is not None:
            return float(raw)
    return None


def _window_samples(
    samples: list[DailyMetricSample],
    *,
    window: BaselineWindow,
    reference_date: date,
) -> list[float]:
    days = WINDOW_DAYS[window]
    start = reference_date - timedelta(days=days - 1)
    return [sample.value for sample in samples if start <= sample.local_date <= reference_date]


def _baseline_confidence(sample_size: int, window_days: int) -> float:
    if sample_size <= 0 or window_days <= 0:
        return 0.0
    return min(1.0, sample_size / float(window_days))


def compute_baselines(inputs: BaselineInputs) -> tuple[list[PersonalBaseline], list[str]]:
    reference_date = inputs.reference_date or date.today()
    baselines: list[PersonalBaseline] = []
    reason_codes: list[str] = []

    for metric_series in inputs.series:
        for window in BaselineWindow:
            window_days = WINDOW_DAYS[window]
            values = _window_samples(
                metric_series.samples,
                window=window,
                reference_date=reference_date,
            )
            sample_size = len(values)
            if sample_size >= MIN_BASELINE_SAMPLES:
                baselines.append(
                    PersonalBaseline(
                        metric=metric_series.metric,
                        window=window,
                        value=round(median(values), 2),
                        sampleSize=sample_size,
                        confidence=round(_baseline_confidence(sample_size, window_days), 3),
                        available=True,
                    )
                )
                reason_codes.append("baseline_from_user_data")
            else:
                baselines.append(
                    PersonalBaseline(
                        metric=metric_series.metric,
                        window=window,
                        value=None,
                        sampleSize=sample_size,
                        confidence=0.0,
                        available=False,
                    )
                )
                reason_codes.append("insufficient_wearable_samples")

    if not inputs.series:
        reason_codes.append("no_wearable_aggregates")

    reason_codes.append("association_not_causation")
    return baselines, _sanitize_reason_codes(sorted(set(reason_codes)))


def compute_protected_days(events: list[ProtectedDayEvent]) -> tuple[ProtectedDaysSummary, list[str]]:
    if not events:
        return (
            ProtectedDaysSummary(available=False),
            _sanitize_reason_codes(["no_structured_protected_day_events", "association_not_causation"]),
        )

    counts = {
        ProtectedDayEventType.HIGH_RISK_PERIOD_AVOIDED: 0,
        ProtectedDayEventType.WORKOUT_MOVED: 0,
        ProtectedDayEventType.VENTILATION_WINDOW_USED: 0,
        ProtectedDayEventType.POOR_AIR_EXPOSURE_REDUCED: 0,
    }
    for event in events:
        counts[event.event_type] = counts.get(event.event_type, 0) + 1

    return (
        ProtectedDaysSummary(
            highRiskPeriodsAvoided=counts[ProtectedDayEventType.HIGH_RISK_PERIOD_AVOIDED],
            workoutsMoved=counts[ProtectedDayEventType.WORKOUT_MOVED],
            ventilationWindowsUsed=counts[ProtectedDayEventType.VENTILATION_WINDOW_USED],
            poorAirExposureReduced=counts[ProtectedDayEventType.POOR_AIR_EXPOSURE_REDUCED],
            available=True,
        ),
        _sanitize_reason_codes(["protected_days_from_structured_events", "association_not_causation"]),
    )


def build_baseline_inputs_from_metric_rows(
    metric_rows: list[dict],
    *,
    sleep_rows: list[dict] | None = None,
    reference_date: date | None = None,
) -> BaselineInputs:
    """Map repository rows into baseline series without inventing missing metrics."""
    ref = reference_date or date.today()
    by_metric: dict[PersonalBaselineMetric, list[DailyMetricSample]] = {}

    hrv_method: str | None = None
    for row in metric_rows:
        metric_type = str(row.get("metric_type") or "")
        value = _metric_value_from_row(row)
        local_date = row.get("local_date")
        if value is None or local_date is None:
            continue

        if metric_type == "resting_heart_rate":
            key = PersonalBaselineMetric.RESTING_HEART_RATE
        elif metric_type == "hrv_sdnn":
            key = PersonalBaselineMetric.HRV
            hrv_method = "sdnn"
        elif metric_type == "hrv_rmssd" and hrv_method != "sdnn":
            key = PersonalBaselineMetric.HRV
        elif metric_type == "steps":
            key = PersonalBaselineMetric.STEPS
        elif metric_type == "exercise_minutes":
            key = PersonalBaselineMetric.EXERCISE_MINUTES
        elif metric_type == "sleep_total":
            key = PersonalBaselineMetric.SLEEP_MINUTES
        else:
            continue

        by_metric.setdefault(key, []).append(DailyMetricSample(local_date=local_date, value=value))

    if sleep_rows:
        sleep_samples = by_metric.setdefault(PersonalBaselineMetric.SLEEP_MINUTES, [])
        existing_dates = {sample.local_date for sample in sleep_samples}
        for row in sleep_rows:
            local_date = row.get("local_date")
            total_minutes = row.get("total_minutes")
            if local_date is None or total_minutes is None or local_date in existing_dates:
                continue
            sleep_samples.append(DailyMetricSample(local_date=local_date, value=float(total_minutes)))

    series = [
        BaselineMetricSeries(metric=metric, samples=samples)
        for metric, samples in by_metric.items()
        if samples
    ]
    return BaselineInputs(series=series, reference_date=ref)


def build_adaptation_snapshot(
    *,
    profile_id: str,
    baseline_inputs: BaselineInputs,
    protected_events: list[ProtectedDayEvent] | None = None,
    generated_at: str | None = None,
) -> PersonalAdaptationSnapshot:
    baselines, baseline_reasons = compute_baselines(baseline_inputs)
    protected_days, protected_reasons = compute_protected_days(protected_events or [])
    reason_codes = _sanitize_reason_codes(sorted(set(baseline_reasons + protected_reasons)))
    return PersonalAdaptationSnapshot(
        profileId=profile_id,
        generatedAt=generated_at or datetime.now(tz=UTC).isoformat(),
        baselines=baselines,
        protectedDays=protected_days,
        reasonCodes=reason_codes,
    )


def now_utc_iso() -> str:
    return datetime.now(tz=UTC).isoformat()
