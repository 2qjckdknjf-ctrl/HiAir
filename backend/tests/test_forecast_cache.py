from datetime import datetime

from app.models.forecast import EnvironmentalForecast, ForecastFreshness, ForecastQuality
from app.services.forecast.cache import ForecastCache, STALE_WHILE_REVALIDATE_SECONDS


def _forecast() -> EnvironmentalForecast:
    return EnvironmentalForecast(
        current=None,
        hourly=[],
        timezone="Europe/Madrid",
        lat=41.39,
        lon=2.17,
        generated_at="2026-07-15T00:00:00+02:00",
        fetched_at="2026-07-15T00:00:00+02:00",
        freshness=ForecastFreshness.LIVE,
        quality=ForecastQuality.PARTIAL,
        sources=["openmeteo_weather"],
    )


def test_cache_hit_within_ttl() -> None:
    cache = ForecastCache()
    cache.put(41.39, 2.17, 24, _forecast())
    result = cache.get(41.39, 2.17, 24, ttl_seconds=900, allow_stale=False)
    assert result is not None
    forecast, freshness, age = result
    assert freshness == ForecastFreshness.CACHED
    assert age >= 0
    assert forecast.timezone == "Europe/Madrid"


def test_cache_miss_when_ttl_expired_without_stale() -> None:
    cache = ForecastCache()
    cache.put(41.39, 2.17, 24, _forecast())
    entry = cache._entries[next(iter(cache._entries))]
    entry.stored_at = datetime.fromisoformat("2020-01-01T00:00:00+00:00")
    assert cache.get(41.39, 2.17, 24, ttl_seconds=900, allow_stale=False) is None


def test_cache_stale_within_policy() -> None:
    cache = ForecastCache()
    cache.put(41.39, 2.17, 24, _forecast())
    entry = cache._entries[next(iter(cache._entries))]
    from datetime import timedelta, timezone

    entry.stored_at = datetime.now(timezone.utc) - timedelta(seconds=STALE_WHILE_REVALIDATE_SECONDS - 10)
    result = cache.get(41.39, 2.17, 24, ttl_seconds=900, allow_stale=True)
    assert result is not None
    _, freshness, _ = result
    assert freshness == ForecastFreshness.STALE
