"""HiAir 2.0 — Work / B2B occupational heat safety models (additive).

Consumer heat index and occupational WBGT are distinct metrics. Never conflate them.
"""

from enum import Enum

from pydantic import BaseModel, Field

from app.models.air import RiskLevel


class WorkloadCategory(str, Enum):
    LIGHT = "light"
    MODERATE = "moderate"
    HEAVY = "heavy"
    VERY_HEAVY = "very_heavy"


class WorkRestRecommendation(BaseModel):
    workMinutes: int = Field(ge=0)
    restMinutes: int = Field(ge=0)
    rationaleCodes: list[str] = Field(default_factory=list)


class WorkSafetyEnvironmentInput(BaseModel):
    """Occupational assessment inputs.

    Prefer measured WBGT. Estimated meteo WBGT is allowed only when labeled via
    ``wbgt_estimated=True`` and must never be presented as instrument WBGT.
    """

    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    wbgt_c: float | None = None
    wbgt_estimated: bool = False
    heat_index_c: float | None = None


class SiteRiskAssessment(BaseModel):
    siteId: str
    wbgtC: float | None = None
    heatIndexC: float | None = None
    workload: WorkloadCategory
    riskLevel: RiskLevel
    workRest: WorkRestRecommendation
    availableMetrics: list[str] = Field(default_factory=list)
    missingMetrics: list[str] = Field(default_factory=list)
    reasonCodes: list[str] = Field(default_factory=list)


class SiteRiskResponse(BaseModel):
    assessedAt: str
    environmentalSource: str | None = None
    assessment: SiteRiskAssessment


class WorkSiteCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    timezone: str | None = None


class WorkSite(BaseModel):
    id: str
    userId: str
    name: str
    lat: float
    lon: float
    timezone: str | None = None
    createdAt: str | None = None


class WorkSiteListResponse(BaseModel):
    sites: list[WorkSite] = Field(default_factory=list)


class WorkSiteWbgtIngestRequest(BaseModel):
    wbgtC: float = Field(ge=-50, le=60)
    measuredAt: str
    source: str = "instrument"
