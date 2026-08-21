from pydantic import BaseModel


class HourlyRiskItem(BaseModel):
    hour_iso: str
    score: int
    level: str


class SafeWindow(BaseModel):
    start_hour_iso: str
    end_hour_iso: str


class DailyPlannerResponse(BaseModel):
    persona: str
    base_lat: float
    base_lon: float
    hourly: list[HourlyRiskItem]
    safe_windows: list[SafeWindow]
    timezone: str | None = None
    dataQuality: str | None = None
    freshness: str | None = None
    sources: list[str] | None = None
    forecastAvailable: bool = True
