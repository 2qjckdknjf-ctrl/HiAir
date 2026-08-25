"""HiAir 1.2 — Best Time / Activity Planner contracts (additive)."""

from enum import Enum

from pydantic import BaseModel, Field


class ActivityType(str, Enum):
    RUNNING = "running"
    WALKING = "walking"
    CYCLING = "cycling"
    HIKING = "hiking"
    DOG_WALK = "dog_walk"
    PLAYGROUND = "playground"
    OUTDOOR_SPORT = "outdoor_sport"
    BEACH = "beach"
    OUTDOOR_WORK = "outdoor_work"
    VENTILATION = "ventilation"


class ActivityIntensity(str, Enum):
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"


class ActivityWindowTier(str, Enum):
    BEST = "best"
    ACCEPTABLE = "acceptable"
    AVOID = "avoid"


class ActivityCatalogItem(BaseModel):
    activity: ActivityType
    defaultDurationMinutes: int
    defaultIntensity: ActivityIntensity
    outdoor: bool = True


class ActivityPlanRequest(BaseModel):
    profileId: str
    activity: ActivityType
    durationMinutes: int | None = Field(default=None, ge=15, le=480)
    intensity: ActivityIntensity | None = None
    earliestStart: str | None = None
    latestStart: str | None = None
    placeId: str | None = None


class ActivityHourAssessment(BaseModel):
    hour: str
    tier: ActivityWindowTier
    score: int = Field(ge=0, le=100)
    reasonCodes: list[str] = Field(default_factory=list)


class ActivityWindow(BaseModel):
    tier: ActivityWindowTier
    start: str
    end: str
    score: int = Field(ge=0, le=100)
    reasonCodes: list[str] = Field(default_factory=list)
    confidence: float = Field(ge=0.0, le=1.0)


class ActivityPlanResponse(BaseModel):
    profileId: str
    activity: ActivityType
    intensity: ActivityIntensity
    durationMinutes: int
    timezone: str
    forecastAvailable: bool
    dataQuality: str | None = None
    freshness: str | None = None
    sources: list[str] = Field(default_factory=list)
    missingMetrics: list[str] = Field(default_factory=list)
    generatedAt: str | None = None
    hourly: list[ActivityHourAssessment] = Field(default_factory=list)
    windows: list[ActivityWindow] = Field(default_factory=list)
    recommendedStart: str | None = None
    personalLoadScore: int | None = None
    personalLoadLevel: str | None = None
    personalLoadReasonCodes: list[str] = Field(default_factory=list)


class ActivityCatalogResponse(BaseModel):
    activities: list[ActivityCatalogItem]
