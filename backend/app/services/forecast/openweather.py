"""OpenWeather current adapter. Hourly is unavailable: 5-day/3-hour is not an hourly forecast."""

from __future__ import annotations

from app.core.settings import settings
from app.models.forecast import (
    EnvironmentalDataKind,
    EnvironmentalForecastPoint,
    ForecastQuality,
    MetricProvenance,
)
from app.services.forecast.http import (
    WEATHER_POINT_FIELDS,
    JsonFetcher,
    default_fetcher,
    missing_metrics_for,
    optional_float,
)
from app.services.forecast.timeutil import utcnow_iso

OPENWEATHER_CURRENT_URL = "https://api.openweathermap.org/data/2.5/weather"


class OpenWeatherProvider:
    name = "openweathermap"

    def __init__(self, fetcher: JsonFetcher | None = None, api_key: str | None = None) -> None:
        self._fetcher = fetcher or default_fetcher()
        self._api_key = api_key if api_key is not None else settings.weather_api_key

    def get_current(self, lat: float, lon: float) -> EnvironmentalForecastPoint:
        if not self._api_key:
            raise ValueError("WEATHER_API_KEY is missing")
        payload = self._fetcher(
            OPENWEATHER_CURRENT_URL,
            {"lat": lat, "lon": lon, "appid": self._api_key, "units": "metric"},
        )
        main = payload.get("main") or {}
        wind = payload.get("wind") or {}
        fetched_at = utcnow_iso()
        dt = payload.get("dt")
        timestamp = fetched_at
        if isinstance(dt, (int, float)):
            from datetime import datetime, timezone

            timestamp = datetime.fromtimestamp(dt, tz=timezone.utc).isoformat()
        kwargs = {
            "temperature_c": optional_float(main.get("temp")),
            "apparent_temperature_c": optional_float(main.get("feels_like")),
            "relative_humidity_pct": optional_float(main.get("humidity")),
            "dew_point_c": None,
            "wind_speed_mps": optional_float(wind.get("speed")),
            "wind_gust_mps": optional_float(wind.get("gust")),
            "uv_index": None,
        }
        missing = missing_metrics_for(kwargs, WEATHER_POINT_FIELDS)
        return EnvironmentalForecastPoint(
            timestamp=timestamp,
            timezone="UTC",
            lat=lat,
            lon=lon,
            provenance=MetricProvenance(
                provider=self.name,
                product="weather.2.5",
                observed_at=timestamp,
                fetched_at=fetched_at,
                kind=EnvironmentalDataKind.OBSERVED,
            ),
            missing_metrics=missing,
            quality=ForecastQuality.PARTIAL,
            **kwargs,
        )

    def get_hourly(self, lat: float, lon: float, hours: int = 48) -> list[EnvironmentalForecastPoint]:
        del lat, lon, hours
        # 5-day/3-hour is not hourly. Do not interpolate.
        return []
