from datetime import datetime, timezone

from app.core.settings import settings
from app.models.air import EnvironmentalInput, UserProfileContext
from app.models.risk import EnvironmentSnapshot
import app.services.air_repository as air_repository
from app.services.environment_service import build_sample_snapshot, fetch_live_snapshot

SOURCE_LIVE = "live"
SOURCE_CACHED = "cached"
SOURCE_SAMPLE = "sample"


def _snapshot_to_environmental(
    snapshot: EnvironmentSnapshot,
    lat: float,
    lon: float,
    timezone_name: str,
) -> EnvironmentalInput:
    feels_like = snapshot.feels_like if snapshot.feels_like is not None else snapshot.temperature_c
    return EnvironmentalInput(
        lat=lat,
        lon=lon,
        temperature=snapshot.temperature_c,
        feels_like=feels_like,
        humidity=snapshot.humidity_percent,
        aqi=snapshot.aqi,
        pm25=snapshot.pm25,
        pm10=snapshot.pm10,
        ozone=snapshot.ozone,
        no2=snapshot.no2,
        uv=snapshot.uv,
        wind_speed=snapshot.wind_speed,
        pollen_grains_m3=snapshot.pollen_grains_m3,
        wildfire_pm10=snapshot.wildfire_pm10,
        source=snapshot.source,
        timestamp=datetime.now(timezone.utc).isoformat(),
        timezone=snapshot.timezone or timezone_name,
    )


def _with_meteo_wbgt_if_missing(snapshot: EnvironmentSnapshot) -> EnvironmentSnapshot:
    """Fill meteo WBGT on cache rows written before WBGT columns existed."""
    if snapshot.wbgt_c is not None:
        return snapshot
    from app.services.wbgt_estimate import estimate_outdoor_wbgt_c

    wbgt_c = estimate_outdoor_wbgt_c(
        snapshot.temperature_c,
        snapshot.humidity_percent,
        wind_speed_ms=snapshot.wind_speed,
        shortwave_wm2=snapshot.shortwave_wm2,
    )
    if wbgt_c is None:
        return snapshot
    return snapshot.model_copy(update={"wbgt_c": wbgt_c, "wbgt_estimated": True})


def _cache_missing_post_migration_fields(snapshot: EnvironmentSnapshot) -> bool:
    """True when a geo-cache row predates pollen/smoke/WBGT persistence."""
    return (
        snapshot.pollen_grains_m3 is None
        and snapshot.wildfire_pm10 is None
        and snapshot.wbgt_c is None
        and snapshot.shortwave_wm2 is None
    )


def _honest_cached_snapshot(cached: EnvironmentSnapshot) -> EnvironmentSnapshot | None:
    """Return an honesty-labeled snapshot from a DB row, or None if unusable."""
    original_source = str(cached.source or "").strip().lower()
    # Never re-label persisted sample/mock rows as "cached" — that would
    # serve synthetic air data under a live/cache honesty label.
    if original_source in (SOURCE_SAMPLE, "mock"):
        if settings.environment_allow_sample_fallback:
            return _with_meteo_wbgt_if_missing(
                EnvironmentSnapshot(
                    temperature_c=cached.temperature_c,
                    humidity_percent=cached.humidity_percent,
                    aqi=cached.aqi,
                    pm25=cached.pm25,
                    ozone=cached.ozone,
                    source=SOURCE_SAMPLE,
                    pm10=cached.pm10,
                    no2=cached.no2,
                    uv=cached.uv,
                    wind_speed=cached.wind_speed,
                    feels_like=cached.feels_like,
                    timezone=cached.timezone,
                    pollen_grains_m3=cached.pollen_grains_m3,
                    wildfire_pm10=cached.wildfire_pm10,
                    wbgt_c=cached.wbgt_c,
                    wbgt_estimated=cached.wbgt_estimated,
                    shortwave_wm2=cached.shortwave_wm2,
                )
            )
        return None
    return _with_meteo_wbgt_if_missing(
        EnvironmentSnapshot(
            temperature_c=cached.temperature_c,
            humidity_percent=cached.humidity_percent,
            aqi=cached.aqi,
            pm25=cached.pm25,
            ozone=cached.ozone,
            source=SOURCE_CACHED,
            pm10=cached.pm10,
            no2=cached.no2,
            uv=cached.uv,
            wind_speed=cached.wind_speed,
            feels_like=cached.feels_like,
            timezone=cached.timezone,
            pollen_grains_m3=cached.pollen_grains_m3,
            wildfire_pm10=cached.wildfire_pm10,
            wbgt_c=cached.wbgt_c,
            wbgt_estimated=cached.wbgt_estimated,
            shortwave_wm2=cached.shortwave_wm2,
        )
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
                # Pre-migration cache rows lack pollen/smoke/WBGT columns entirely;
                # do not keep serving them for the full TTL — refresh live once.
                if _cache_missing_post_migration_fields(cached_row):
                    pass
                else:
                    return honest
            if honest is not None and honest.source == SOURCE_SAMPLE:
                deferred_sample = honest

    try:
        live = fetch_live_snapshot(lat, lon)
        resolved = EnvironmentSnapshot(
            temperature_c=live.temperature_c,
            humidity_percent=live.humidity_percent,
            aqi=live.aqi,
            pm25=live.pm25,
            ozone=live.ozone,
            source=SOURCE_LIVE,
            pm10=live.pm10,
            no2=live.no2,
            uv=live.uv,
            wind_speed=live.wind_speed,
            feels_like=live.feels_like,
            timezone=live.timezone,
            pollen_grains_m3=live.pollen_grains_m3,
            wildfire_pm10=live.wildfire_pm10,
            wbgt_c=live.wbgt_c,
            wbgt_estimated=live.wbgt_estimated,
            shortwave_wm2=live.shortwave_wm2,
        )
        try:
            air_repository.save_resolved_environment_snapshot(resolved, lat=lat, lon=lon)
        except Exception:
            # Cache write must never fail the live response.
            pass
        return resolved
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
