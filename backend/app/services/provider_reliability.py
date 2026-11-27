"""Provider reliability monitoring scaffold: alert → investigate → validate → fix → verify."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum


class ReliabilityStage(str, Enum):
    ALERT = "alert"
    INVESTIGATE = "investigate"
    VALIDATE = "validate"
    FIX = "fix"
    VERIFY = "verify"
    CLOSED = "closed"


class ReliabilitySignal(str, Enum):
    STALE_AQI = "stale_aqi"
    MISSING_API_DATA = "missing_api_data"
    FALSE_ZERO = "false_zero"
    PROVIDER_OUTAGE = "provider_outage"


@dataclass
class ReliabilityIncident:
    incident_id: str
    provider: str
    signal: ReliabilitySignal
    detected_at: str
    stage: ReliabilityStage = ReliabilityStage.ALERT
    notes: list[str] = field(default_factory=list)
    independent_validation_passed: bool | None = None
    fix_applied: bool = False
    post_fix_verified: bool | None = None

    def advance(self, note: str) -> None:
        order = list(ReliabilityStage)
        idx = order.index(self.stage)
        if idx >= len(order) - 1:
            return
        self.stage = order[idx + 1]
        self.notes.append(note)

    def record_validation(self, *, passed: bool, note: str) -> None:
        if self.stage != ReliabilityStage.VALIDATE:
            raise RuntimeError("validation only allowed in VALIDATE stage")
        self.independent_validation_passed = passed
        self.notes.append(note)
        if passed:
            self.advance("validation_passed")
        else:
            self.notes.append("validation_failed_hold")

    def record_fix(self, note: str) -> None:
        if self.stage != ReliabilityStage.FIX:
            raise RuntimeError("fix only allowed in FIX stage")
        self.fix_applied = True
        self.notes.append(note)
        self.advance("fix_recorded")

    def record_post_fix_verification(self, *, passed: bool, note: str) -> None:
        if self.stage != ReliabilityStage.VERIFY:
            raise RuntimeError("post-fix verification only allowed in VERIFY stage")
        self.post_fix_verified = passed
        self.notes.append(note)
        if passed:
            self.advance("verified_closed")


def classify_provider_reading(
    *,
    aqi: int | None,
    raw_aqi_token: str | None,
    age_seconds: int | None,
    stale_after_seconds: int = 3600,
    provider_reachable: bool = True,
) -> ReliabilitySignal | None:
    """Map a single reading into a reliability signal without mutating Risk Engine thresholds."""
    if not provider_reachable:
        return ReliabilitySignal.PROVIDER_OUTAGE
    if age_seconds is not None and age_seconds > stale_after_seconds:
        return ReliabilitySignal.STALE_AQI
    if raw_aqi_token is not None and str(raw_aqi_token).strip() in {"", "-", "null", "None"}:
        # Empty/sentinel must be missing, never a numeric zero.
        return ReliabilitySignal.MISSING_API_DATA
    if aqi is None:
        return ReliabilitySignal.MISSING_API_DATA
    if aqi == 0 and raw_aqi_token is not None and str(raw_aqi_token).strip().lower() in {"n/a", "unknown"}:
        return ReliabilitySignal.FALSE_ZERO
    return None


def open_incident(provider: str, signal: ReliabilitySignal, incident_id: str) -> ReliabilityIncident:
    return ReliabilityIncident(
        incident_id=incident_id,
        provider=provider,
        signal=signal,
        detected_at=datetime.now(timezone.utc).isoformat(),
    )
