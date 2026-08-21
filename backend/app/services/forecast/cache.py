"""In-memory geo-keyed forecast cache. No new database."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from threading import Lock

from app.models.forecast import EnvironmentalForecast, ForecastFreshness

STALE_WHILE_REVALIDATE_SECONDS = 2 * 60 * 60


def cache_key(lat: float, lon: float, hours: int) -> str:
    return f"{round(lat, 2)}:{round(lon, 2)}:{hours}"


@dataclass
class _CacheEntry:
    forecast: EnvironmentalForecast
    stored_at: datetime


class ForecastCache:
    def __init__(self) -> None:
        self._entries: dict[str, _CacheEntry] = {}
        self._lock = Lock()

    def get(
        self,
        lat: float,
        lon: float,
        hours: int,
        ttl_seconds: int,
        *,
        allow_stale: bool,
    ) -> tuple[EnvironmentalForecast, ForecastFreshness, int] | None:
        key = cache_key(lat, lon, hours)
        now = datetime.now(timezone.utc)
        with self._lock:
            entry = self._entries.get(key)
            if entry is None:
                return None
            age = int((now - entry.stored_at).total_seconds())
            if age <= ttl_seconds:
                return entry.forecast, ForecastFreshness.CACHED, age
            if allow_stale and age <= STALE_WHILE_REVALIDATE_SECONDS:
                return entry.forecast, ForecastFreshness.STALE, age
            return None

    def put(self, lat: float, lon: float, hours: int, forecast: EnvironmentalForecast) -> None:
        key = cache_key(lat, lon, hours)
        with self._lock:
            self._entries[key] = _CacheEntry(
                forecast=forecast,
                stored_at=datetime.now(timezone.utc),
            )

    def clear(self) -> None:
        with self._lock:
            self._entries.clear()


forecast_cache = ForecastCache()
