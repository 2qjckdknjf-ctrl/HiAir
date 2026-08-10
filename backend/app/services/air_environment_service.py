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


def _honest_cached_snapshot(cached: EnvironmentSnapshot) -> EnvironmentSnapshot | None:
    """Return an honesty-labeled snapshot from a DB row, or None if unusable."""
    original_source = str(cached.source or "").strip().lower()
    # Never re-label persisted sample/mock rows as "cached" — that would
    # serve synthetic air data under a live/cache honesty label.
    if original_source in (SOURCE_SAMPLE, "mock"):
        if settings.environment_allow_sample_fallback:
            return EnvironmentSnapshot(
                temperature_c=cached.temperature_c,
                humidity_percent=cached.humidity_percent,
                aqi=cached.aqi,
                pm25=cached.pm25,
                ozone=cached.ozone,
                source=SOURCE_SAMPLE,
            )
        return None
    return EnvironmentSnapshot(
        temperature_c=cached.temperature_c,
        humidity_percent=cached.humidity_percent,
        aqi=cached.aqi,
        pm25=cached.pm25,
        ozone=cached.ozone,
        source=SOURCE_CACHED,
    )


def resolve_environment_snapshot(
    lat: float,
    lon: float,
    *,
    prefer_live: bool = True,
    force_refresh: bool = False,
) -> EnvironmentSnapshot:
    """Resolve environmental conditions: fresh cache → live → sample fallback.

    Within ``environment_cache_ttl_seconds``, serve DB cache immediately (label
    ``cached``) so dashboard cold-start does not wait on Open-Meteo. Live
    providers run on cache miss or ``force_refresh``. Sample remains last-resort
    and honesty-gated.
    """
    del prefer_live  # retained for call-site compatibility; cache-first is default
    deferred_sample: EnvironmentSnapshot | None = None

    if not force_refresh:
        cached_row = air_repository.get_latest_environment_snapshot(
            lat=lat,
            lon=lon,
            max_age_seconds=settings.environment_cache_ttl_seconds,
        )
        if cached_row is not None:
            honest = _honest_cached_snapshot(cached_row)
            if honest is not None and honest.source == SOURCE_CACHED:
                return honest
            if honest is not None and honest.source == SOURCE_SAMPLE:
                deferred_sample = honest

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
        pass

    if deferred_sample is not None:
        return deferred_sample

    if force_refresh:
        late_cached = air_repository.get_latest_environment_snapshot(
            lat=lat,
            lon=lon,
            max_age_seconds=settings.environment_cache_ttl_seconds,
        )
        if late_cached is not None:
            honest = _honest_cached_snapshot(late_cached)
            if honest is not None:
                return honest

    if not settings.environment_allow_sample_fallback:
        raise RuntimeError("Environmental data unavailable and sample fallback is disabled")

    return build_sample_snapshot(lat, lon)


def load_environment(
    profile: UserProfileContext,
    *,
    force_live: bool = False,
    force_refresh: bool = False,
) -> EnvironmentalInput:
    """Load environmental input for a profile using the cache → live → sample chain."""
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
