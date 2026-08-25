"""Canonical environmental forecast models for HiAir 1.1 Forecast Truth."""

from enum import Enum

from pydantic import BaseModel, Field


class EnvironmentalDataKind(str, Enum):
    OBSERVED = "observed"
    FORECAST = "forecast"
    DERIVED = "derived"
    CACHED = "cached"


class ForecastFreshness(str, Enum):
    LIVE = "live"
    CACHED = "cached"
    STALE = "stale"


class ForecastQuality(str, Enum):
    COMPLETE = "complete"
    PARTIAL = "partial"
    UNAVAILABLE = "unavailable"


class MetricProvenance(BaseModel):
    provider: str
    product: str | None = None
    observed_at: str | None = None
    forecast_for: str | None = None
    issued_at: str | None = None
    fetched_at: str
    kind: EnvironmentalDataKind
    cache_age_seconds: int | None = None


class EnvironmentalForecastPoint(BaseModel):
    timestamp: str
    timezone: str
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    temperature_c: float | None = None
    apparent_temperature_c: float | None = None
    relative_humidity_pct: float | None = None
    dew_point_c: float | None = None
    wind_speed_mps: float | None = None
    wind_gust_mps: float | None = None
    uv_index: float | None = None
    aqi: int | None = None
    pm25_ugm3: float | None = None
    pm10_ugm3: float | None = None
    ozone_ugm3: float | None = None
    no2_ugm3: float | None = None
    provenance: MetricProvenance | None = None
    missing_metrics: list[str] = Field(default_factory=list)
    quality: ForecastQuality = ForecastQuality.PARTIAL


class EnvironmentalForecast(BaseModel):
    current: EnvironmentalForecastPoint | None = None
    hourly: list[EnvironmentalForecastPoint] = Field(default_factory=list)
    timezone: str
    lat: float
    lon: float
    generated_at: str
    fetched_at: str
    freshness: ForecastFreshness = ForecastFreshness.LIVE
    quality: ForecastQuality = ForecastQuality.UNAVAILABLE
    sources: list[str] = Field(default_factory=list)
    missing_metrics: list[str] = Field(default_factory=list)
    cache_age_seconds: int | None = None
    provider_summary: str = ""
