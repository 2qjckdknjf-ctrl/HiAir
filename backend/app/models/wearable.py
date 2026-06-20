from datetime import datetime

from pydantic import BaseModel, Field


class WearableMetricsSubmitRequest(BaseModel):
    profile_id: str | None = None
    recorded_at: datetime | None = None
    steps: int | None = Field(default=None, ge=0)
    resting_heart_rate_bpm: int | None = Field(default=None, ge=30, le=220)
    hrv_ms: float | None = Field(default=None, ge=0)
    sleep_hours: float | None = Field(default=None, ge=0, le=24)
    sleep_quality_score: int | None = Field(default=None, ge=1, le=5)
    source: str = "mobile"


class WearableMetricsResponse(BaseModel):
    id: str
    user_id: str
    profile_id: str | None
    recorded_at: datetime
    steps: int | None
    resting_heart_rate_bpm: int | None
    hrv_ms: float | None
    sleep_hours: float | None
    sleep_quality_score: int | None
    source: str


class WearableMetricsLatestResponse(BaseModel):
    available: bool
    metrics: WearableMetricsResponse | None = None
