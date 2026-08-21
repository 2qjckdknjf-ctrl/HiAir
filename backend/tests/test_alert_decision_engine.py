"""Tests for HiAir 1.4 alert decision engine."""

from app.models.alert_decision import AlertCandidate, AlertDecisionAction, AlertDecisionReason
from app.services.alert_decision_engine import decide_alert


def _candidate(**overrides) -> AlertCandidate:
    base = dict(
        alertType="air_worsening",
        severity="medium",
        reasonCode=AlertDecisionReason.THRESHOLD_CROSSED,
        profileId="profile-1",
        localHour=10,
        quietHoursStart=22,
        quietHoursEnd=7,
        cooldownMinutesRemaining=0,
        alreadySentFingerprint=None,
        fingerprint="air_worsening:2026-08-21T10",
        actionable=True,
        personalThresholdMet=True,
    )
    base.update(overrides)
    return AlertCandidate(**base)


def test_send_when_actionable_and_outside_quiet_hours() -> None:
    decision = decide_alert(_candidate())
    assert decision.action == AlertDecisionAction.SEND
    assert decision.shouldNotify is True
    assert AlertDecisionReason.THRESHOLD_CROSSED.value in decision.reasonCodes


def test_suppress_cooldown() -> None:
    decision = decide_alert(_candidate(cooldownMinutesRemaining=30))
    assert decision.action == AlertDecisionAction.SUPPRESS
    assert AlertDecisionReason.COOLDOWN_ACTIVE.value in decision.reasonCodes


def test_suppress_quiet_hours_wrap() -> None:
    decision = decide_alert(_candidate(localHour=23))
    assert decision.action == AlertDecisionAction.SUPPRESS
    assert AlertDecisionReason.QUIET_HOURS.value in decision.reasonCodes


def test_suppress_duplicate_fingerprint() -> None:
    decision = decide_alert(
        _candidate(
            fingerprint="same",
            alreadySentFingerprint="same",
        )
    )
    assert decision.action == AlertDecisionAction.SUPPRESS
    assert AlertDecisionReason.DUPLICATE.value in decision.reasonCodes


def test_suppress_non_actionable() -> None:
    decision = decide_alert(_candidate(actionable=False))
    assert decision.action == AlertDecisionAction.SUPPRESS
    assert AlertDecisionReason.NO_ACTIONABLE_CHANGE.value in decision.reasonCodes
