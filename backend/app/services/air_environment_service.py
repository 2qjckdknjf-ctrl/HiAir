from datetime import datetime, timezone

from app.models.air import EnvironmentalInput, UserProfileContext
from app.services.environment_service import build_mock_snapshot, fetch_live_snapshot


def _estimate_feels_like(temperature: float, humidity: float) -> float:
    # Lightweight approximation for deterministic MVP.
    humidity_delta = max(0.0, humidity - 40.0) * 0.05
    return round(temperature + humidity_delta, 1)


def load_environment(profile: UserProfileContext, force_live: bool) -> EnvironmentalInput:
    lat = profile.home_lat
    lon = profile.home_lon
    snapshot = fetch_live_snapshot(lat, lon) if force_live else build_mock_snapshot(lat, lon)

    feels_like = _estimate_feels_like(snapshot.temperature_c, snapshot.humidity_percent)
    pm10 = round(snapshot.pm25 * 1.45, 1)
    uv = round(max(0.0, (snapshot.temperature_c - 16) / 2.5), 1)
    wind_speed = round(max(0.2, 1.0 + (snapshot.humidity_percent / 100 * 2.8)), 1)

    return EnvironmentalInput(
        lat=lat,
        lon=lon,
        temperature=snapshot.temperature_c,
        feels_like=feels_like,
        humidity=snapshot.humidity_percent,
        aqi=snapshot.aqi,
        pm25=snapshot.pm25,
        pm10=pm10,
        ozone=snapshot.ozone,
        uv=uv,
        wind_speed=wind_speed,
        source=snapshot.source,
        timestamp=datetime.now(timezone.utc).isoformat(),
        timezone=profile.timezone,
    )
