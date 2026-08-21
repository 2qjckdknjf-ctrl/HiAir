"""HiAir 1.4 — Alert Decision Engine models (additive)."""

from enum import Enum

from pydantic import BaseModel, Field


class AlertDecisionAction(str, Enum):
    SEND = "send"
    SUPPRESS = "suppress"


class AlertDecisionReason(str, Enum):
    THRESHOLD_CROSSED = "threshold_crossed"
    SIGNIFICANT_CHANGE = "significant_change"
    BEST_WINDOW_OPENED = "best_window_opened"
    HAZARD_ESCALATED = "hazard_escalated"
    COOLDOWN_ACTIVE = "cooldown_active"
    QUIET_HOURS = "quiet_hours"
    DUPLICATE = "duplicate"
    BELOW_PERSONAL_THRESHOLD = "below_personal_threshold"
    NO_ACTIONABLE_CHANGE = "no_actionable_change"


class AlertCandidate(BaseModel):
    alertType: str
    severity: str = "medium"
    reasonCode: AlertDecisionReason
    profileId: str
    localHour: int = Field(ge=0, le=23)
    quietHoursStart: int | None = Field(default=None, ge=0, le=23)
    quietHoursEnd: int | None = Field(default=None, ge=0, le=23)
    cooldownMinutesRemaining: int = Field(default=0, ge=0)
    alreadySentFingerprint: str | None = None
    fingerprint: str
    actionable: bool = True
    personalThresholdMet: bool = True


class AlertDecision(BaseModel):
    action: AlertDecisionAction
    reasonCodes: list[str] = Field(default_factory=list)
    alertType: str
    fingerprint: str
    shouldNotify: bool


class AlertDecisionRequest(BaseModel):
    candidate: AlertCandidate


class AlertDecisionResponse(BaseModel):
    decision: AlertDecision
