"""Map canonical forecast points onto the existing EnvironmentalInput risk contract."""

from __future__ import annotations

from datetime import datetime

from app.models.air import EnvironmentalInput
from app.models.forecast import EnvironmentalDataKind, EnvironmentalForecast, EnvironmentalForecastPoint
from app.models.risk import EnvironmentSnapshot
from app.services.forecast.timeutil import is_hour_upcoming


def forecast_point_to_environmental(point: EnvironmentalForecastPoint) -> EnvironmentalInput | None:
    """Return a risk-engine input, or None when there is not even a temperature to score heat."""
    if point.temperature_c is None:
        return None
    feels_like = (
        point.apparent_temperature_c
        if point.apparent_temperature_c is not None
        else point.temperature_c
    )
    humidity = point.relative_humidity_pct
    kind = point.provenance.kind.value if point.provenance else EnvironmentalDataKind.FORECAST.value
    source = "cached" if kind == EnvironmentalDataKind.CACHED.value else kind
    if point.provenance and point.provenance.kind == EnvironmentalDataKind.OBSERVED:
        source = "live"
    return EnvironmentalInput(
        lat=point.lat,
        lon=point.lon,
        temperature=point.temperature_c,
        feels_like=feels_like,
        humidity=humidity,
        aqi=point.aqi,
        pm25=point.pm25_ugm3,
        pm10=point.pm10_ugm3,
        ozone=point.ozone_ugm3,
        no2=point.no2_ugm3,
        uv=point.uv_index,
        wind_speed=point.wind_speed_mps,
        # Forecast points do not carry CAMS pollen / wildfire smoke — set
        # explicitly so response serialization never drops the honesty keys,
        # then callers merge live values via retain_live_only_metrics().
        pollen_grains_m3=None,
        wildfire_pm10=None,
        source=source,
        timestamp=point.timestamp,
        timezone=point.timezone,
    )


def retain_live_only_metrics(
    mapped: EnvironmentalInput,
    live: EnvironmentalInput,
) -> EnvironmentalInput:
    """Keep live CAMS pollen / wildfire smoke when forecast overlay replaces current."""
    return mapped.model_copy(
        update={
            "pollen_grains_m3": (
                mapped.pollen_grains_m3
                if mapped.pollen_grains_m3 is not None
                else live.pollen_grains_m3
            ),
            "wildfire_pm10": (
                mapped.wildfire_pm10
                if mapped.wildfire_pm10 is not None
                else live.wildfire_pm10
            ),
        }
    )


def overlay_forecast_current(
    live: EnvironmentalInput,
    forecast: EnvironmentalForecast | None,
) -> EnvironmentalInput:
    """Merge forecast.current onto live env, retaining CAMS pollen/smoke honesty."""
    if forecast is None or forecast.current is None:
        return live
    mapped = forecast_point_to_environmental(forecast.current)
    if mapped is None:
        return live
    freshness = (
        forecast.freshness.value
        if hasattr(forecast.freshness, "value")
        else str(forecast.freshness)
    )
    return apply_freshness_source(
        retain_live_only_metrics(mapped, live),
        freshness,
    )


def forecast_point_to_snapshot(point: EnvironmentalForecastPoint, source: str) -> EnvironmentSnapshot | None:
    if (
        point.temperature_c is None
        or point.relative_humidity_pct is None
        or point.aqi is None
        or point.pm25_ugm3 is None
        or point.ozone_ugm3 is None
    ):
        return None
    return EnvironmentSnapshot(
        temperature_c=point.temperature_c,
        humidity_percent=point.relative_humidity_pct,
        aqi=point.aqi,
        pm25=point.pm25_ugm3,
        ozone=point.ozone_ugm3,
        source=source,
        pm10=point.pm10_ugm3,
        uv=point.uv_index,
        wind_speed=point.wind_speed_mps,
        feels_like=point.apparent_temperature_c,
        timezone=point.timezone,
    )


def apply_freshness_source(environment: EnvironmentalInput, freshness: str) -> EnvironmentalInput:
    if freshness in ("cached", "stale"):
        return environment.model_copy(update={"source": "cached"})
    if freshness == "live":
        return environment.model_copy(update={"source": "live"})
    return environment


def forecast_to_hourly_inputs(
    forecast: EnvironmentalForecast,
    *,
    from_now: bool = True,
    now: datetime | None = None,
    max_hours: int | None = None,
) -> list[EnvironmentalInput]:
    points: list[EnvironmentalInput] = []
    for item in forecast.hourly:
        mapped = forecast_point_to_environmental(item)
        if mapped is None:
            continue
        if from_now and not is_hour_upcoming(mapped.timestamp, now):
            continue
        points.append(mapped)
        if max_hours is not None and len(points) >= max_hours:
            break
    return points
