from enum import Enum

from pydantic import BaseModel, Field

from app.models.air import EnvironmentalInput


class HazardType(str, Enum):
    HEAT = "heat"
    AIR = "air"
    UV = "uv"
    POLLEN = "pollen"
    SMOKE = "smoke"
    DUST = "dust"


class HazardLevel(str, Enum):
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"
    VERY_HIGH = "very_high"
    UNAVAILABLE = "unavailable"


HAZARD_LEVEL_ORDER: dict[HazardLevel, int] = {
    HazardLevel.UNAVAILABLE: -1,
    HazardLevel.LOW: 0,
    HazardLevel.MODERATE: 1,
    HazardLevel.HIGH: 2,
    HazardLevel.VERY_HIGH: 3,
}


class HazardScore(BaseModel):
    hazard: HazardType
    level: HazardLevel
    score: int = Field(ge=0, le=100)
    available: bool = True
    reasonCodes: list[str] = Field(default_factory=list)
    unavailableReason: str | None = None


class MultiHazardAssessment(BaseModel):
    profileId: str
    assessedAt: str
    hazards: list[HazardScore]
    overallLevel: HazardLevel
    overallScore: int = Field(ge=0, le=100)
    availableCount: int = Field(ge=0)
    reasonCodes: list[str] = Field(default_factory=list)


class HazardsResponse(BaseModel):
    profileId: str
    assessedAt: str
    environmental: EnvironmentalInput
    assessment: MultiHazardAssessment
    dataQuality: str | None = None
    freshness: str | None = None
    sources: list[str] | None = None
    generatedAt: str | None = None
