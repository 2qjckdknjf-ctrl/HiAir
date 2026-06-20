from pydantic import BaseModel, Field


class RiskBreakdownFactor(BaseModel):
    key: str
    label_ru: str
    label_en: str
    points: int = Field(ge=0)


class RiskBreakdownResponse(BaseModel):
    profile_id: str | None
    total_score: int = Field(ge=0, le=100)
    risk_level: str
    factors: list[RiskBreakdownFactor]


class MorningBriefingResponse(BaseModel):
    profile_id: str | None
    language: str
    risk_level: str
    risk_score: int = Field(ge=0, le=100)
    temperature_c: float
    aqi: int
    summary: str
    best_walk_window: str | None = None
    avoid_outdoor_window: str | None = None
    personal_note: str
    wearable_note: str | None = None


class PersonalInsightItem(BaseModel):
    insight_type: str
    title_ru: str
    title_en: str
    body_ru: str
    body_en: str
    confidence: str


class PersonalPatternsResponse(BaseModel):
    profile_id: str
    days_observed: int
    minimum_days_required: int = 7
    ready: bool
    status_ru: str
    status_en: str
    insights: list[PersonalInsightItem]
