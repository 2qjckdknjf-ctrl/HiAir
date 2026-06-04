from datetime import date, datetime
from enum import Enum

from pydantic import BaseModel, Field


class WearablePlatform(str, Enum):
    IOS = "ios"
    ANDROID = "android"


class WearableSource(str, Enum):
    APPLE_HEALTH = "apple_health"
    HEALTH_CONNECT = "health_connect"


class WearableConsentRequest(BaseModel):
    platform: WearablePlatform
    source: WearableSource
    stepsEnabled: bool = False
    heartRateEnabled: bool = False
    restingHeartRateEnabled: bool = False
    hrvEnabled: bool = False
    sleepEnabled: bool = False
    consentVersion: str = Field(default="wearables-v1", min_length=1, max_length=64)


class WearableConsentResponse(BaseModel):
    id: str
    userId: str
    platform: WearablePlatform
    source: WearableSource
    stepsEnabled: bool
    heartRateEnabled: bool
    restingHeartRateEnabled: bool
    hrvEnabled: bool
    sleepEnabled: bool
    consentVersion: str
    acceptedAt: datetime | None
    revokedAt: datetime | None
    isActive: bool


class WearableDailySummaryRequest(BaseModel):
    date: date
    stepsTotal: int | None = Field(default=None, ge=0, le=100_000)
    stepsGoal: int | None = Field(default=None, ge=0, le=100_000)
    heartRateAvg: float | None = Field(default=None, ge=30, le=230)
    heartRateMin: float | None = Field(default=None, ge=25, le=220)
    heartRateMax: float | None = Field(default=None, ge=30, le=240)
    restingHeartRateAvg: float | None = Field(default=None, ge=30, le=140)
    restingHeartRateDelta: float | None = None
    hrvAvg: float | None = Field(default=None, ge=0, le=300)
    sleepMinutes: int | None = Field(default=None, ge=0, le=1440)
    source: WearableSource


class WearableHourlySummaryRequest(BaseModel):
    hourStart: datetime
    stepsTotal: int | None = Field(default=None, ge=0, le=50_000)
    heartRateAvg: float | None = Field(default=None, ge=30, le=230)
    heartRateMax: float | None = Field(default=None, ge=30, le=240)
    source: WearableSource


class WearableDailySummaryResponse(BaseModel):
    id: str
    date: date
    stepsTotal: int | None
    stepsGoal: int | None
    heartRateAvg: float | None
    heartRateMin: float | None
    heartRateMax: float | None
    restingHeartRateAvg: float | None
    restingHeartRateDelta: float | None
    source: WearableSource


class PersonalLoadSummary(BaseModel):
    score: int = Field(ge=0, le=100)
    level: str
    explanations: list[str]
    reasonCodes: list[str]


class WearableTodayResponse(BaseModel):
    consent: WearableConsentResponse | None
    dailySummary: WearableDailySummaryResponse | None
    stepsLastHour: int | None = None
    stepsLast3Hours: int | None = None
    restingHeartRateBaseline7d: float | None = None
    restingHeartRateBaseline30d: float | None = None
    personalLoad: PersonalLoadSummary | None = None


class WearableDataDeleteResponse(BaseModel):
    deletedDaily: int
    deletedHourly: int
    consentRevoked: bool
