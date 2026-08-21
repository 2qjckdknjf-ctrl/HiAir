"""Map canonical forecast points onto the existing EnvironmentalInput risk contract."""

from __future__ import annotations

from app.models.air import EnvironmentalInput
from app.models.forecast import EnvironmentalDataKind, EnvironmentalForecastPoint
from app.models.risk import EnvironmentSnapshot


def forecast_point_to_environmental(point: EnvironmentalForecastPoint) -> EnvironmentalInput | None:
    """Return a risk-engine input, or None when there is not even a temperature to score heat."""
    if point.temperature_c is None:
        return None
    feels_like = (
        point.apparent_temperature_c
        if point.apparent_temperature_c is not None
        else point.temperature_c
    )
    humidity = point.relative_humidity_pct if point.relative_humidity_pct is not None else 0.0
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
        uv=point.uv_index,
        wind_speed=point.wind_speed_mps,
        source=source,
        timestamp=point.timestamp,
        timezone=point.timezone,
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
