from enum import Enum

from pydantic import BaseModel, Field


class RiskLevel(str, Enum):
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"
    VERY_HIGH = "very_high"


class ProfileType(str, Enum):
    ADULT_DEFAULT = "adult_default"
    CHILD = "child"
    ELDERLY = "elderly"
    ASTHMA_SENSITIVE = "asthma_sensitive"
    ALLERGY_SENSITIVE = "allergy_sensitive"
    RUNNER = "runner"
    OUTDOOR_WORKER = "outdoor_worker"


class SafeWindowType(str, Enum):
    WALK = "walk"
    RUN = "run"
    VENTILATION = "ventilation"
    GENERAL_OUTDOOR = "general_outdoor"


class AlertType(str, Enum):
    RISK_INCREASE = "risk_increase"
    SAFE_WINDOW_OPEN = "safe_window_open"
    VENTILATION_WINDOW_OPEN = "ventilation_window_open"
    CAUTION_FOR_PROFILE = "caution_for_profile"
    EVENING_SUMMARY = "evening_summary"
    NEXT_DAY_WARNING = "next_day_warning"


class AlertSeverity(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL_NON_MEDICAL = "critical_non_medical"


class UserProfileContext(BaseModel):
    profile_id: str
    user_id: str
    profile_type: ProfileType
    age_group: str = "adult"
    heat_sensitivity_level: int = Field(default=2, ge=1, le=5)
    respiratory_sensitivity_level: int = Field(default=2, ge=1, le=5)
    activity_level: str = "moderate"
    location_name: str | None = None
    timezone: str = "UTC"
    home_lat: float = 0.0
    home_lon: float = 0.0


class EnvironmentalInput(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    temperature: float
    feels_like: float
    humidity: float = Field(ge=0, le=100)
    aqi: int = Field(ge=0)
    pm25: float = Field(ge=0)
    pm10: float = Field(ge=0)
    ozone: float = Field(ge=0)
    uv: float = Field(ge=0)
    wind_speed: float = Field(ge=0)
    source: str
    timestamp: str
    timezone: str = "UTC"


class SafeWindow(BaseModel):
    type: SafeWindowType
    start: str
    end: str
    confidence: float = Field(ge=0.0, le=1.0)


class RiskAssessmentResult(BaseModel):
    overallRisk: RiskLevel
    heatRisk: RiskLevel
    airRisk: RiskLevel
    outdoorRisk: RiskLevel
    indoorVentilationRisk: RiskLevel
    safeWindows: list[SafeWindow]
    recommendationFlags: list[str]
    reasonCodes: list[str]


class RecommendationCard(BaseModel):
    headline: str
    summary: str
    actions: list[str]


class CurrentRiskResponse(BaseModel):
    profileId: str
    assessedAt: str
    environmental: EnvironmentalInput
    risk: RiskAssessmentResult
    recommendation: RecommendationCard
    explanation: str
    explanationSource: str


class HourlyRiskPoint(BaseModel):
    hour: str
    overallRisk: RiskLevel


class DayPlanResponse(BaseModel):
    profileId: str
    timezone: str
    hourlyRisk: list[HourlyRiskPoint]
    safeWindows: list[SafeWindow]
    ventilationWindows: list[SafeWindow]


class RecommendationResponse(BaseModel):
    profileId: str
    recommendation: RecommendationCard
    risk: RiskAssessmentResult
    generatedAt: str


class RecomputeRiskRequest(BaseModel):
    profileId: str = Field(alias="profileId")
    forceRefresh: bool = Field(default=False, alias="forceRefresh")


class AlertEvaluateRequest(BaseModel):
    profileId: str = Field(alias="profileId")
    risk: RiskAssessmentResult
    recommendation: RecommendationCard


class AlertDecision(BaseModel):
    shouldSend: bool
    alertType: AlertType | None
    severity: AlertSeverity | None
    title: str
    body: str
    dedupeKey: str
    reason: str


class AlertEvaluateResponse(BaseModel):
    profileId: str
    decision: AlertDecision
    dispatchedToTokens: int = 0
    skipped: bool = True
    dispatchReason: str = "not_dispatched"


class SymptomCreateRequest(BaseModel):
    profileId: str = Field(alias="profileId")
    symptomType: str = Field(alias="symptomType")
    intensity: int = Field(ge=1, le=5)
    note: str | None = None


class SymptomHistoryItem(BaseModel):
    id: str
    profileId: str
    symptomType: str
    intensity: int
    note: str | None
    loggedAt: str


class SymptomHistoryResponse(BaseModel):
    profileId: str
    items: list[SymptomHistoryItem]


class PersonalPatternInsight(BaseModel):
    factorA: str
    factorB: str
    coefficient: float
    pValue: float
    sampleSize: int
    humanReadableText: str


class PersonalPatternsResponse(BaseModel):
    profileId: str
    windowDays: int
    generatedAt: str
    items: list[PersonalPatternInsight]
