from __future__ import annotations

from typing import Any, Callable

import httpx

JsonFetcher = Callable[[str, dict[str, Any]], dict[str, Any]]


def default_fetcher(timeout_seconds: float = 15.0) -> JsonFetcher:
    def _get(url: str, params: dict[str, Any]) -> dict[str, Any]:
        with httpx.Client(timeout=timeout_seconds) as client:
            response = client.get(url, params=params)
            response.raise_for_status()
            payload = response.json()
            if not isinstance(payload, dict):
                raise ValueError("provider response is not a JSON object")
            return payload

    return _get


def optional_float(value: Any) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def optional_int(value: Any) -> int | None:
    number = optional_float(value)
    if number is None:
        return None
    return int(round(number))


WEATHER_POINT_FIELDS = (
    "temperature_c",
    "apparent_temperature_c",
    "relative_humidity_pct",
    "dew_point_c",
    "wind_speed_mps",
    "wind_gust_mps",
    "uv_index",
)

AIR_POINT_FIELDS = (
    "aqi",
    "pm25_ugm3",
    "pm10_ugm3",
    "ozone_ugm3",
    "no2_ugm3",
)

ALL_METRIC_FIELDS = WEATHER_POINT_FIELDS + AIR_POINT_FIELDS


def missing_metrics_for(point_kwargs: dict[str, Any], fields: tuple[str, ...] = ALL_METRIC_FIELDS) -> list[str]:
    return [name for name in fields if point_kwargs.get(name) is None]
