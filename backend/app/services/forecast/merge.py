from __future__ import annotations

from datetime import datetime, timezone

from app.models.forecast import (
    EnvironmentalDataKind,
    EnvironmentalForecastPoint,
    ForecastQuality,
    MetricProvenance,
)
from app.services.forecast.http import ALL_METRIC_FIELDS, missing_metrics_for


def hour_key(timestamp: str) -> str:
    parsed = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc).replace(minute=0, second=0, microsecond=0).isoformat()


def merge_points(
    weather: EnvironmentalForecastPoint | None,
    air: EnvironmentalForecastPoint | None,
    *,
    fallback_lat: float,
    fallback_lon: float,
    fallback_timezone: str,
    fetched_at: str,
    kind: EnvironmentalDataKind,
) -> EnvironmentalForecastPoint:
    base = weather or air
    if base is None:
        raise ValueError("cannot merge empty weather and air points")
    kwargs = {
        "temperature_c": weather.temperature_c if weather else None,
        "apparent_temperature_c": weather.apparent_temperature_c if weather else None,
        "relative_humidity_pct": weather.relative_humidity_pct if weather else None,
        "dew_point_c": weather.dew_point_c if weather else None,
        "wind_speed_mps": weather.wind_speed_mps if weather else None,
        "wind_gust_mps": weather.wind_gust_mps if weather else None,
        "uv_index": weather.uv_index if weather else None,
        "aqi": air.aqi if air else None,
        "pm25_ugm3": air.pm25_ugm3 if air else None,
        "pm10_ugm3": air.pm10_ugm3 if air else None,
        "ozone_ugm3": air.ozone_ugm3 if air else None,
        "no2_ugm3": air.no2_ugm3 if air else None,
    }
    missing = missing_metrics_for(kwargs, ALL_METRIC_FIELDS)
    providers = []
    if weather is not None:
        providers.append(weather.provenance.provider if weather.provenance else "weather")
    if air is not None:
        providers.append(air.provenance.provider if air.provenance else "air")
    return EnvironmentalForecastPoint(
        timestamp=base.timestamp,
        timezone=base.timezone or fallback_timezone,
        lat=base.lat if base.lat is not None else fallback_lat,
        lon=base.lon if base.lon is not None else fallback_lon,
        provenance=MetricProvenance(
            provider="+".join(providers) if providers else "merged",
            product="normalized",
            observed_at=base.timestamp if kind == EnvironmentalDataKind.OBSERVED else None,
            forecast_for=base.timestamp if kind == EnvironmentalDataKind.FORECAST else None,
            fetched_at=fetched_at,
            kind=kind,
        ),
        missing_metrics=missing,
        quality=ForecastQuality.COMPLETE if not missing else ForecastQuality.PARTIAL,
        **kwargs,
    )


def merge_hourly(
    weather_points: list[EnvironmentalForecastPoint],
    air_points: list[EnvironmentalForecastPoint],
    *,
    lat: float,
    lon: float,
    timezone_name: str,
    fetched_at: str,
) -> list[EnvironmentalForecastPoint]:
    weather_by_hour = {hour_key(point.timestamp): point for point in weather_points}
    air_by_hour = {hour_key(point.timestamp): point for point in air_points}
    keys = sorted(set(weather_by_hour) | set(air_by_hour))
    merged: list[EnvironmentalForecastPoint] = []
    for key in keys:
        weather = weather_by_hour.get(key)
        air = air_by_hour.get(key)
        if weather is None and air is None:
            continue
        merged.append(
            merge_points(
                weather,
                air,
                fallback_lat=lat,
                fallback_lon=lon,
                fallback_timezone=timezone_name,
                fetched_at=fetched_at,
                kind=EnvironmentalDataKind.FORECAST,
            )
        )
    return merged
