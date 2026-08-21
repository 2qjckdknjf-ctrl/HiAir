"""HiAir 1.4 Alert Decision Engine.

Deterministic anti-spam gate: cooldown, quiet hours, dedupe, personal threshold,
and actionability. Does not send notifications itself.
"""

from __future__ import annotations

from app.models.alert_decision import (
    AlertCandidate,
    AlertDecision,
    AlertDecisionAction,
    AlertDecisionReason,
)


def _in_quiet_hours(local_hour: int, start: int | None, end: int | None) -> bool:
    if start is None or end is None:
        return False
    if start == end:
        return False
    if start < end:
        return start <= local_hour < end
    # Wraps midnight, e.g. 22 → 07
    return local_hour >= start or local_hour < end


def decide_alert(candidate: AlertCandidate) -> AlertDecision:
    reasons: list[str] = []

    if candidate.cooldownMinutesRemaining > 0:
        reasons.append(AlertDecisionReason.COOLDOWN_ACTIVE.value)
        return AlertDecision(
            action=AlertDecisionAction.SUPPRESS,
            reasonCodes=reasons,
            alertType=candidate.alertType,
            fingerprint=candidate.fingerprint,
            shouldNotify=False,
        )

    if _in_quiet_hours(candidate.localHour, candidate.quietHoursStart, candidate.quietHoursEnd):
        reasons.append(AlertDecisionReason.QUIET_HOURS.value)
        return AlertDecision(
            action=AlertDecisionAction.SUPPRESS,
            reasonCodes=reasons,
            alertType=candidate.alertType,
            fingerprint=candidate.fingerprint,
            shouldNotify=False,
        )

    if (
        candidate.alreadySentFingerprint is not None
        and candidate.alreadySentFingerprint == candidate.fingerprint
    ):
        reasons.append(AlertDecisionReason.DUPLICATE.value)
        return AlertDecision(
            action=AlertDecisionAction.SUPPRESS,
            reasonCodes=reasons,
            alertType=candidate.alertType,
            fingerprint=candidate.fingerprint,
            shouldNotify=False,
        )

    if not candidate.personalThresholdMet:
        reasons.append(AlertDecisionReason.BELOW_PERSONAL_THRESHOLD.value)
        return AlertDecision(
            action=AlertDecisionAction.SUPPRESS,
            reasonCodes=reasons,
            alertType=candidate.alertType,
            fingerprint=candidate.fingerprint,
            shouldNotify=False,
        )

    if not candidate.actionable:
        reasons.append(AlertDecisionReason.NO_ACTIONABLE_CHANGE.value)
        return AlertDecision(
            action=AlertDecisionAction.SUPPRESS,
            reasonCodes=reasons,
            alertType=candidate.alertType,
            fingerprint=candidate.fingerprint,
            shouldNotify=False,
        )

    reasons.append(candidate.reasonCode.value)
    return AlertDecision(
        action=AlertDecisionAction.SEND,
        reasonCodes=reasons,
        alertType=candidate.alertType,
        fingerprint=candidate.fingerprint,
        shouldNotify=True,
    )
