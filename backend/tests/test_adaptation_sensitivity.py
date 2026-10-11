"""Tests for HiAir 1.6 baseline → alert sensitivity wiring."""

from app.services.adaptation_sensitivity import (
    effective_alert_threshold,
    more_sensitive_alert_threshold,
)
from app.services.personal_load_engine import PersonalLoadInput, compute_personal_load_score


def test_more_sensitive_steps_down_one_level() -> None:
    assert more_sensitive_alert_threshold("very_high") == "high"
    assert more_sensitive_alert_threshold("high") == "medium"
    assert more_sensitive_alert_threshold("medium") == "medium"


def test_effective_threshold_no_boost_without_baseline_strain() -> None:
    load = compute_personal_load_score(
        PersonalLoadInput(steps_today=9_000, heat_index=33, consent_active=True)
    )
    threshold, reasons = effective_alert_threshold("high", load)
    assert threshold == "high"
    assert reasons == []


def test_effective_threshold_boosts_when_resting_hr_above_baseline() -> None:
    load = compute_personal_load_score(
        PersonalLoadInput(
            resting_heart_rate=80,
            resting_heart_rate_baseline_7d=68,
            consent_active=True,
        )
    )
    assert load.score >= 15
    assert "resting_hr_above_7d_baseline" in load.reason_codes
    threshold, reasons = effective_alert_threshold("very_high", load)
    assert threshold == "high"
    assert "alert_threshold_boosted_from_baselines" in reasons
    assert "resting_hr_above_7d_baseline" in reasons


def test_sleep_below_personal_baseline_scores_and_boosts_alerts() -> None:
    load = compute_personal_load_score(
        PersonalLoadInput(
            sleep_minutes=300,
            sleep_minutes_baseline_7d=420,
            consent_active=True,
        )
    )
    assert "sleep_below_7d_baseline" in load.reason_codes
    threshold, reasons = effective_alert_threshold("high", load)
    assert threshold == "medium"
    assert "sleep_below_7d_baseline" in reasons


def test_effective_threshold_noop_when_load_missing() -> None:
    threshold, reasons = effective_alert_threshold("high", None)
    assert threshold == "high"
    assert reasons == []
