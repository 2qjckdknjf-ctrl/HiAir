from datetime import datetime, timezone

from app.core.settings import settings
from app.models.air import EnvironmentalInput, UserProfileContext
from app.models.risk import EnvironmentSnapshot
import app.services.air_repository as air_repository
from app.services.environment_service import build_sample_snapshot, fetch_live_snapshot

SOURCE_LIVE = "live"
SOURCE_CACHED = "cached"
SOURCE_SAMPLE = "sample"


def _estimate_feels_like(temperature: float, humidity: float) -> float:
    humidity_delta = max(0.0, humidity - 40.0) * 0.05
    return round(temperature + humidity_delta, 1)


def _snapshot_to_environmental(
    snapshot: EnvironmentSnapshot,
    lat: float,
    lon: float,
    timezone_name: str,
) -> EnvironmentalInput:
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
        timezone=timezone_name,
    )


def resolve_environment_snapshot(
    lat: float,
    lon: float,
    *,
    prefer_live: bool = True,
    force_refresh: bool = False,
) -> EnvironmentSnapshot:
    """Resolve environmental conditions: live providers → DB cache → sample fallback."""
    if prefer_live or force_refresh:
        try:
            live = fetch_live_snapshot(lat, lon)
            return EnvironmentSnapshot(
                temperature_c=live.temperature_c,
                humidity_percent=live.humidity_percent,
                aqi=live.aqi,
                pm25=live.pm25,
                ozone=live.ozone,
                source=SOURCE_LIVE,
            )
        except Exception:
            if force_refresh:
                pass

    cached = air_repository.get_latest_environment_snapshot(
        lat=lat,
        lon=lon,
        max_age_seconds=settings.environment_cache_ttl_seconds,
    )
    if cached is not None:
        return EnvironmentSnapshot(
            temperature_c=cached.temperature_c,
            humidity_percent=cached.humidity_percent,
            aqi=cached.aqi,
            pm25=cached.pm25,
            ozone=cached.ozone,
            source=SOURCE_CACHED,
        )

    if not settings.environment_allow_sample_fallback:
        raise RuntimeError("Environmental data unavailable and sample fallback is disabled")

    return build_sample_snapshot(lat, lon)


def load_environment(
    profile: UserProfileContext,
    *,
    force_live: bool = False,
    force_refresh: bool = False,
) -> EnvironmentalInput:
    """Load environmental input for a profile using the live → cached → sample chain."""
    snapshot = resolve_environment_snapshot(
        profile.home_lat,
        profile.home_lon,
        prefer_live=True,
        force_refresh=force_refresh or force_live,
    )
    return _snapshot_to_environmental(
        snapshot,
        profile.home_lat,
        profile.home_lon,
        profile.timezone,
    )
