"""HiAir 1.6 — Personal Adaptation & Protected Days models (additive)."""

from enum import Enum

from pydantic import BaseModel, Field


class BaselineWindow(str, Enum):
    D7 = "d7"
    D30 = "d30"


class PersonalBaselineMetric(str, Enum):
    RESTING_HEART_RATE = "resting_heart_rate"
    HRV = "hrv"
    SLEEP_MINUTES = "sleep_minutes"
    STEPS = "steps"
    EXERCISE_MINUTES = "exercise_minutes"


class PersonalBaseline(BaseModel):
    metric: PersonalBaselineMetric
    window: BaselineWindow
    value: float | None = None
    sampleSize: int = Field(default=0, ge=0)
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    available: bool = False


class ProtectedDaysSummary(BaseModel):
    highRiskPeriodsAvoided: int = Field(default=0, ge=0)
    workoutsMoved: int = Field(default=0, ge=0)
    ventilationWindowsUsed: int = Field(default=0, ge=0)
    poorAirExposureReduced: int = Field(default=0, ge=0)
    available: bool = False


class PersonalAdaptationSnapshot(BaseModel):
    profileId: str
    generatedAt: str
    baselines: list[PersonalBaseline] = Field(default_factory=list)
    protectedDays: ProtectedDaysSummary
    reasonCodes: list[str] = Field(default_factory=list)


class ProtectedDayEventCreateRequest(BaseModel):
    profileId: str = Field(min_length=1)
    eventType: str = Field(min_length=1)
    eventDate: str | None = None


class ProtectedDayEventRecord(BaseModel):
    id: str
    profileId: str
    eventType: str
    eventDate: str
