"""WAQI current adapter. No hourly pollutant forecast — return empty hourly rather than fabricating."""

from __future__ import annotations

from typing import Any

from app.core.settings import settings
from app.models.forecast import (
    EnvironmentalDataKind,
    EnvironmentalForecastPoint,
    ForecastQuality,
    MetricProvenance,
)
from app.services.forecast.http import (
    AIR_POINT_FIELDS,
    JsonFetcher,
    default_fetcher,
    missing_metrics_for,
    optional_float,
    optional_int,
)
from app.services.forecast.timeutil import utcnow_iso


def _iaqi_value(iaqi: dict[str, Any], key: str) -> Any:
    entry = iaqi.get(key)
    if isinstance(entry, dict):
        return entry.get("v")
    return None


class WaqiAirQualityProvider:
    name = "waqi"

    def __init__(self, fetcher: JsonFetcher | None = None, api_key: str | None = None) -> None:
        self._fetcher = fetcher or default_fetcher()
        self._api_key = api_key if api_key is not None else settings.aqi_api_key

    def get_current(self, lat: float, lon: float) -> EnvironmentalForecastPoint:
        if not self._api_key:
            raise ValueError("AQI_API_KEY is missing")
        payload = self._fetcher(
            f"https://api.waqi.info/feed/geo:{lat};{lon}/",
            {"token": self._api_key},
        )
        data = payload.get("data") or {}
        iaqi = data.get("iaqi") or {}
        fetched_at = utcnow_iso()
        time_block = data.get("time") or {}
        iso = time_block.get("iso")
        timestamp = str(iso) if iso else fetched_at
        kwargs = {
            "aqi": optional_int(data.get("aqi")),
            "pm25_ugm3": optional_float(_iaqi_value(iaqi, "pm25")),
            "pm10_ugm3": optional_float(_iaqi_value(iaqi, "pm10")),
            "ozone_ugm3": optional_float(_iaqi_value(iaqi, "o3")),
            "no2_ugm3": optional_float(_iaqi_value(iaqi, "no2")),
        }
        missing = missing_metrics_for(kwargs, AIR_POINT_FIELDS)
        return EnvironmentalForecastPoint(
            timestamp=timestamp,
            timezone="UTC",
            lat=lat,
            lon=lon,
            provenance=MetricProvenance(
                provider=self.name,
                product="geo-feed",
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
        return []
