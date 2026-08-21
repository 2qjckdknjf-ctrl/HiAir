from __future__ import annotations

from typing import Any

from app.models.forecast import (
    EnvironmentalDataKind,
    EnvironmentalForecastPoint,
    ForecastQuality,
    MetricProvenance,
)
from app.services.forecast.http import (
    AIR_POINT_FIELDS,
    JsonFetcher,
    WEATHER_POINT_FIELDS,
    default_fetcher,
    missing_metrics_for,
    optional_float,
    optional_int,
)
from app.services.forecast.timeutil import attach_timezone, utcnow_iso

OPENMETEO_WEATHER_URL = "https://api.open-meteo.com/v1/forecast"
OPENMETEO_AIR_URL = "https://air-quality-api.open-meteo.com/v1/air-quality"

_WEATHER_VARS = (
    "temperature_2m,apparent_temperature,relative_humidity_2m,"
    "dew_point_2m,wind_speed_10m,wind_gusts_10m,uv_index"
)
_AIR_VARS = "us_aqi,pm2_5,pm10,ozone,nitrogen_dioxide"


def _weather_kwargs(block: dict[str, Any], index: int | None = None) -> dict[str, Any]:
    def _at(key: str) -> Any:
        value = block.get(key)
        if index is None:
            return value
        if not isinstance(value, list) or index >= len(value):
            return None
        return value[index]

    return {
        "temperature_c": optional_float(_at("temperature_2m")),
        "apparent_temperature_c": optional_float(_at("apparent_temperature")),
        "relative_humidity_pct": optional_float(_at("relative_humidity_2m")),
        "dew_point_c": optional_float(_at("dew_point_2m")),
        "wind_speed_mps": optional_float(_at("wind_speed_10m")),
        "wind_gust_mps": optional_float(_at("wind_gusts_10m")),
        "uv_index": optional_float(_at("uv_index")),
    }


def _air_kwargs(block: dict[str, Any], index: int | None = None) -> dict[str, Any]:
    def _at(key: str) -> Any:
        value = block.get(key)
        if index is None:
            return value
        if not isinstance(value, list) or index >= len(value):
            return None
        return value[index]

    return {
        "aqi": optional_int(_at("us_aqi")),
        "pm25_ugm3": optional_float(_at("pm2_5")),
        "pm10_ugm3": optional_float(_at("pm10")),
        "ozone_ugm3": optional_float(_at("ozone")),
        "no2_ugm3": optional_float(_at("nitrogen_dioxide")),
    }


class OpenMeteoWeatherProvider:
    name = "openmeteo_weather"

    def __init__(self, fetcher: JsonFetcher | None = None) -> None:
        self._fetcher = fetcher or default_fetcher()

    def _fetch(self, lat: float, lon: float, hours: int) -> dict[str, Any]:
        # +1 day buffer so mid-afternoon clips still leave a full upcoming window.
        forecast_days = max(1, min(8, (max(hours, 1) + 23) // 24 + 1))
        return self._fetcher(
            OPENMETEO_WEATHER_URL,
            {
                "latitude": lat,
                "longitude": lon,
                "current": _WEATHER_VARS,
                "hourly": _WEATHER_VARS,
                "forecast_days": forecast_days,
                "timezone": "auto",
                "wind_speed_unit": "ms",
            },
        )

    def get_current(self, lat: float, lon: float) -> EnvironmentalForecastPoint:
        payload = self._fetch(lat, lon, hours=24)
        return self._current_from_payload(payload, lat, lon)

    def get_hourly(self, lat: float, lon: float, hours: int = 48) -> list[EnvironmentalForecastPoint]:
        payload = self._fetch(lat, lon, hours=hours)
        return self._hourly_from_payload(payload, lat, lon, hours)

    def fetch_bundle(
        self, lat: float, lon: float, hours: int = 48
    ) -> tuple[EnvironmentalForecastPoint, list[EnvironmentalForecastPoint]]:
        payload = self._fetch(lat, lon, hours=hours)
        return self._current_from_payload(payload, lat, lon), self._hourly_from_payload(
            payload, lat, lon, hours
        )

    def _current_from_payload(
        self, payload: dict[str, Any], lat: float, lon: float
    ) -> EnvironmentalForecastPoint:
        timezone_name = str(payload.get("timezone") or "UTC")
        current = payload.get("current") or {}
        fetched_at = utcnow_iso()
        time_raw = str(current.get("time") or "")
        timestamp = attach_timezone(time_raw, timezone_name) if time_raw else fetched_at
        kwargs = _weather_kwargs(current)
        missing = missing_metrics_for(kwargs, WEATHER_POINT_FIELDS)
        return EnvironmentalForecastPoint(
            timestamp=timestamp,
            timezone=timezone_name,
            lat=lat,
            lon=lon,
            provenance=MetricProvenance(
                provider=self.name,
                product="forecast",
                observed_at=timestamp,
                fetched_at=fetched_at,
                kind=EnvironmentalDataKind.OBSERVED,
            ),
            missing_metrics=missing,
            quality=ForecastQuality.COMPLETE if not missing else ForecastQuality.PARTIAL,
            **kwargs,
        )

    def _hourly_from_payload(
        self,
        payload: dict[str, Any],
        lat: float,
        lon: float,
        hours: int,
    ) -> list[EnvironmentalForecastPoint]:
        timezone_name = str(payload.get("timezone") or "UTC")
        hourly = payload.get("hourly") or {}
        times = hourly.get("time") or []
        fetched_at = utcnow_iso()
        points: list[EnvironmentalForecastPoint] = []
        for index, time_raw in enumerate(times[:hours]):
            timestamp = attach_timezone(str(time_raw), timezone_name)
            kwargs = _weather_kwargs(hourly, index)
            missing = missing_metrics_for(kwargs, WEATHER_POINT_FIELDS)
            points.append(
                EnvironmentalForecastPoint(
                    timestamp=timestamp,
                    timezone=timezone_name,
                    lat=lat,
                    lon=lon,
                    provenance=MetricProvenance(
                        provider=self.name,
                        product="forecast",
                        forecast_for=timestamp,
                        fetched_at=fetched_at,
                        kind=EnvironmentalDataKind.FORECAST,
                    ),
                    missing_metrics=missing,
                    quality=ForecastQuality.COMPLETE if not missing else ForecastQuality.PARTIAL,
                    **kwargs,
                )
            )
        return points


class OpenMeteoAirQualityProvider:
    name = "openmeteo_air"

    def __init__(self, fetcher: JsonFetcher | None = None) -> None:
        self._fetcher = fetcher or default_fetcher()

    def _fetch(self, lat: float, lon: float, hours: int) -> dict[str, Any]:
        forecast_days = max(1, min(5, (max(hours, 1) + 23) // 24 + 1))
        return self._fetcher(
            OPENMETEO_AIR_URL,
            {
                "latitude": lat,
                "longitude": lon,
                "current": _AIR_VARS,
                "hourly": _AIR_VARS,
                "forecast_days": forecast_days,
                "timezone": "auto",
            },
        )

    def get_current(self, lat: float, lon: float) -> EnvironmentalForecastPoint:
        payload = self._fetch(lat, lon, hours=24)
        return self._current_from_payload(payload, lat, lon)

    def get_hourly(self, lat: float, lon: float, hours: int = 48) -> list[EnvironmentalForecastPoint]:
        payload = self._fetch(lat, lon, hours=hours)
        return self._hourly_from_payload(payload, lat, lon, hours)

    def fetch_bundle(
        self, lat: float, lon: float, hours: int = 48
    ) -> tuple[EnvironmentalForecastPoint, list[EnvironmentalForecastPoint]]:
        payload = self._fetch(lat, lon, hours=hours)
        return self._current_from_payload(payload, lat, lon), self._hourly_from_payload(
            payload, lat, lon, hours
        )

    def _current_from_payload(
        self, payload: dict[str, Any], lat: float, lon: float
    ) -> EnvironmentalForecastPoint:
        timezone_name = str(payload.get("timezone") or "UTC")
        current = payload.get("current") or {}
        fetched_at = utcnow_iso()
        time_raw = str(current.get("time") or "")
        timestamp = attach_timezone(time_raw, timezone_name) if time_raw else fetched_at
        kwargs = _air_kwargs(current)
        missing = missing_metrics_for(kwargs, AIR_POINT_FIELDS)
        return EnvironmentalForecastPoint(
            timestamp=timestamp,
            timezone=timezone_name,
            lat=lat,
            lon=lon,
            provenance=MetricProvenance(
                provider=self.name,
                product="air-quality",
                observed_at=timestamp,
                fetched_at=fetched_at,
                kind=EnvironmentalDataKind.OBSERVED,
            ),
            missing_metrics=missing,
            quality=ForecastQuality.COMPLETE if not missing else ForecastQuality.PARTIAL,
            **kwargs,
        )

    def _hourly_from_payload(
        self,
        payload: dict[str, Any],
        lat: float,
        lon: float,
        hours: int,
    ) -> list[EnvironmentalForecastPoint]:
        timezone_name = str(payload.get("timezone") or "UTC")
        hourly = payload.get("hourly") or {}
        times = hourly.get("time") or []
        fetched_at = utcnow_iso()
        points: list[EnvironmentalForecastPoint] = []
        for index, time_raw in enumerate(times[:hours]):
            timestamp = attach_timezone(str(time_raw), timezone_name)
            kwargs = _air_kwargs(hourly, index)
            missing = missing_metrics_for(kwargs, AIR_POINT_FIELDS)
            points.append(
                EnvironmentalForecastPoint(
                    timestamp=timestamp,
                    timezone=timezone_name,
                    lat=lat,
                    lon=lon,
                    provenance=MetricProvenance(
                        provider=self.name,
                        product="air-quality",
                        forecast_for=timestamp,
                        fetched_at=fetched_at,
                        kind=EnvironmentalDataKind.FORECAST,
                    ),
                    missing_metrics=missing,
                    quality=ForecastQuality.COMPLETE if not missing else ForecastQuality.PARTIAL,
                    **kwargs,
                )
            )
        return points
