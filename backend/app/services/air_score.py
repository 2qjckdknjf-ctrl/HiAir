"""Shared helpers for mapping mock environment snapshots into the air-risk engine.

Used by the dashboard and planner routers so the risk-score mapping and the
``EnvironmentSnapshot`` -> ``EnvironmentalInput`` adapter stay in one place.
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
    return EnvironmentalInput(
        lat=lat,
        lon=lon,
        temperature=float(environment.temperature_c),
        feels_like=float(environment.temperature_c + (humidity / 20.0)),
        humidity=humidity,
        aqi=int(environment.aqi),
        pm25=float(environment.pm25),
        pm10=max(1.0, float(environment.pm25) * 1.4),
        ozone=float(environment.ozone),
        uv=4.0,
        wind_speed=2.0,
        source=environment.source,
        timestamp=timestamp,
        timezone="UTC",
    )
