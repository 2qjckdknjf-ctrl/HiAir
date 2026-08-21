"""Tests for HiAir 1.6 personal adaptation engine."""

from datetime import date, timedelta

from app.models.personal_adaptation import BaselineWindow, PersonalBaselineMetric
from app.services.personal_adaptation_engine import (
    BaselineInputs,
    BaselineMetricSeries,
    DailyMetricSample,
    ProtectedDayEvent,
    ProtectedDayEventType,
    build_adaptation_snapshot,
    build_baseline_inputs_from_metric_rows,
    compute_baselines,
    compute_protected_days,
)


def _hrv_samples(n: int, *, start: date | None = None) -> list[DailyMetricSample]:
    base = start or date.today() - timedelta(days=n - 1)
    return [
        DailyMetricSample(local_date=base + timedelta(days=i), value=40.0 + i)
        for i in range(n)
    ]


def test_compute_baselines_unavailable_when_insufficient_samples() -> None:
    inputs = BaselineInputs(
        series=[
            BaselineMetricSeries(
                metric=PersonalBaselineMetric.HRV,
                samples=_hrv_samples(3),
            )
        ],
        reference_date=date.today(),
    )
    baselines, reasons = compute_baselines(inputs)
    d7 = next(item for item in baselines if item.window == BaselineWindow.D7)
    assert d7.available is False
    assert d7.value is None
    assert d7.sampleSize == 3
    assert "insufficient_wearable_samples" in reasons
    assert "association_not_causation" in reasons


def test_compute_baselines_available_with_enough_samples() -> None:
    inputs = BaselineInputs(
        series=[
            BaselineMetricSeries(
                metric=PersonalBaselineMetric.RESTING_HEART_RATE,
                samples=_hrv_samples(8, start=date(2026, 8, 1)),
            )
        ],
        reference_date=date(2026, 8, 8),
    )
    baselines, reasons = compute_baselines(inputs)
    d7 = next(item for item in baselines if item.window == BaselineWindow.D7)
    assert d7.available is True
    assert d7.value is not None
    assert d7.sampleSize == 7
    assert d7.confidence > 0
    assert "baseline_from_user_data" in reasons


def test_compute_baselines_never_invents_missing_metrics() -> None:
    baselines, reasons = compute_baselines(BaselineInputs(series=[]))
    assert baselines == []
    assert "no_wearable_aggregates" in reasons


def test_compute_protected_days_unavailable_without_events() -> None:
    summary, reasons = compute_protected_days([])
    assert summary.available is False
    assert summary.highRiskPeriodsAvoided == 0
    assert summary.workoutsMoved == 0
    assert "no_structured_protected_day_events" in reasons
    assert "association_not_causation" in reasons


def test_compute_protected_days_counts_structured_events_only() -> None:
    events = [
        ProtectedDayEvent(event_type=ProtectedDayEventType.WORKOUT_MOVED),
        ProtectedDayEvent(event_type=ProtectedDayEventType.WORKOUT_MOVED),
        ProtectedDayEvent(event_type=ProtectedDayEventType.VENTILATION_WINDOW_USED),
        ProtectedDayEvent(event_type=ProtectedDayEventType.HIGH_RISK_PERIOD_AVOIDED),
        ProtectedDayEvent(event_type=ProtectedDayEventType.POOR_AIR_EXPOSURE_REDUCED),
    ]
    summary, reasons = compute_protected_days(events)
    assert summary.available is True
    assert summary.workoutsMoved == 2
    assert summary.ventilationWindowsUsed == 1
    assert summary.highRiskPeriodsAvoided == 1
    assert summary.poorAirExposureReduced == 1
    assert "protected_days_from_structured_events" in reasons


def test_build_baseline_inputs_from_metric_rows_prefers_sdnn_hrv() -> None:
    rows = [
        {
            "local_date": date(2026, 8, 1),
            "metric_type": "hrv_rmssd",
            "value_avg": 30.0,
        },
        {
            "local_date": date(2026, 8, 2),
            "metric_type": "hrv_sdnn",
            "value_avg": 42.0,
        },
    ]
    inputs = build_baseline_inputs_from_metric_rows(rows, reference_date=date(2026, 8, 2))
    hrv = next(item for item in inputs.series if item.metric == PersonalBaselineMetric.HRV)
    assert len(hrv.samples) == 2
    assert hrv.samples[-1].value == 42.0


def test_build_adaptation_snapshot_composes_honest_unavailable_state() -> None:
    snapshot = build_adaptation_snapshot(
        profile_id="profile-1",
        baseline_inputs=BaselineInputs(series=[]),
        protected_events=[],
        generated_at="2026-08-21T12:00:00+00:00",
    )
    assert snapshot.profileId == "profile-1"
    assert snapshot.baselines == []
    assert snapshot.protectedDays.available is False
    assert "no_wearable_aggregates" in snapshot.reasonCodes
    assert "association_not_causation" in snapshot.reasonCodes


def test_reason_codes_exclude_diagnosis_language() -> None:
    _, reasons = compute_baselines(BaselineInputs(series=[]))
    assert all("diagnosis" not in code for code in reasons)
