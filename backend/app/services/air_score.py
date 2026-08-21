"""Shared helpers for mapping environment snapshots into the air-risk engine.

Used by the dashboard and planner routers so the risk-score mapping and the
``EnvironmentSnapshot`` -> ``EnvironmentalInput`` adapter stay in one place.
Optional UV/PM10/wind stay null when the provider did not supply them.
"""

from app.models.air import EnvironmentalInput
from app.models.risk import EnvironmentSnapshot

RISK_LEVEL_TO_SCORE: dict[str, int] = {
    "low": 20,
    "moderate": 45,
    "high": 70,
    "very_high": 90,
}


def to_air_environment(
    environment: EnvironmentSnapshot,
    lat: float,
    lon: float,
    timestamp: str = "1970-01-01T00:00:00Z",
) -> EnvironmentalInput:
    humidity = float(environment.humidity_percent)
    feels_like = (
        float(environment.feels_like)
        if environment.feels_like is not None
        else float(environment.temperature_c)
    )
    return EnvironmentalInput(
        lat=lat,
        lon=lon,
        temperature=float(environment.temperature_c),
        feels_like=feels_like,
        humidity=humidity,
        aqi=int(environment.aqi),
        pm25=float(environment.pm25),
        pm10=environment.pm10,
        ozone=float(environment.ozone),
        uv=environment.uv,
        wind_speed=environment.wind_speed,
        source=environment.source,
        timestamp=timestamp,
        timezone=environment.timezone or "UTC",
    )
