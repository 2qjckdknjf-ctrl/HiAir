"""Normalized forecast orchestration: providers → merge → quality → cache."""

from __future__ import annotations

import logging
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from time import perf_counter

from app.core.settings import settings
from app.models.forecast import (
    EnvironmentalDataKind,
    EnvironmentalForecast,
    EnvironmentalForecastPoint,
    ForecastFreshness,
    ForecastQuality,
)
from app.services.forecast.cache import forecast_cache
from app.services.forecast.merge import merge_hourly, merge_points
from app.services.forecast.openmeteo import OpenMeteoAirQualityProvider, OpenMeteoWeatherProvider
from app.services.forecast.openweather import OpenWeatherProvider
from app.services.forecast.quality import classify_forecast
from app.services.forecast.timeutil import upcoming_points, utcnow_iso
from app.services.forecast.waqi import WaqiAirQualityProvider
from app.services.singleflight import SingleFlight

logger = logging.getLogger("hiair.forecast")
_LIVE_FORECAST_FLIGHT = SingleFlight()


def build_weather_provider():
    name = settings.weather_api_provider.lower()
    if name == "openweathermap":
        return OpenWeatherProvider()
    if name == "openmeteo":
        return OpenMeteoWeatherProvider()
    raise ValueError(f"Unsupported weather provider: {settings.weather_api_provider}")


def build_air_provider():
    name = settings.aqi_api_provider.lower()
    if name == "waqi":
        return WaqiAirQualityProvider()
    if name == "openmeteo":
        return OpenMeteoAirQualityProvider()
    raise ValueError(f"Unsupported AQI provider: {settings.aqi_api_provider}")


def _label_cached(
    forecast: EnvironmentalForecast,
    freshness: ForecastFreshness,
    age_seconds: int,
) -> EnvironmentalForecast:
    # Cached and stale responses must not look like a fresh live forecast point.
    kind = EnvironmentalDataKind.CACHED
    hourly = []
    for point in forecast.hourly:
        provenance = point.provenance.model_copy(
            update={"kind": kind, "cache_age_seconds": age_seconds}
        ) if point.provenance else None
        hourly.append(point.model_copy(update={"provenance": provenance}))
    current = forecast.current
    if current is not None and current.provenance is not None:
        current = current.model_copy(
            update={
                "provenance": current.provenance.model_copy(
                    update={"kind": EnvironmentalDataKind.CACHED, "cache_age_seconds": age_seconds}
                )
            }
        )
    return forecast.model_copy(
        update={
            "hourly": hourly,
            "current": current,
            "freshness": freshness,
            "cache_age_seconds": age_seconds,
        }
    )


def _fetch_live(lat: float, lon: float, hours: int) -> EnvironmentalForecast:
    weather_provider = build_weather_provider()
    air_provider = build_air_provider()
    fetched_at = utcnow_iso()
    weather_error: Exception | None = None
    air_error: Exception | None = None
    weather_current: EnvironmentalForecastPoint | None = None
    weather_hourly: list[EnvironmentalForecastPoint] = []
    air_current: EnvironmentalForecastPoint | None = None
    air_hourly: list[EnvironmentalForecastPoint] = []

    def _weather() -> None:
        nonlocal weather_current, weather_hourly, weather_error
        try:
            fetch_bundle = getattr(weather_provider, "fetch_bundle", None)
            if fetch_bundle is not None:
                weather_current, weather_hourly = fetch_bundle(lat, lon, hours)
            else:
                weather_current = weather_provider.get_current(lat, lon)
                weather_hourly = weather_provider.get_hourly(lat, lon, hours)
        except Exception as exc:  # noqa: BLE001 — provider isolation
            weather_error = exc
            logger.warning("forecast_weather_failed provider=%s error_category=provider", weather_provider.name)

    def _air() -> None:
        nonlocal air_current, air_hourly, air_error
        try:
            fetch_bundle = getattr(air_provider, "fetch_bundle", None)
            if fetch_bundle is not None:
                air_current, air_hourly = fetch_bundle(lat, lon, hours)
            else:
                air_current = air_provider.get_current(lat, lon)
                air_hourly = air_provider.get_hourly(lat, lon, hours)
        except Exception as exc:  # noqa: BLE001 — provider isolation
            air_error = exc
            logger.warning("forecast_air_failed provider=%s error_category=provider", air_provider.name)

    started = perf_counter()
    with ThreadPoolExecutor(max_workers=2) as pool:
        weather_future = pool.submit(_weather)
        air_future = pool.submit(_air)
        weather_future.result()
        air_future.result()
    latency_ms = round((perf_counter() - started) * 1000.0, 1)

    timezone_name = "UTC"
    if weather_current is not None:
        timezone_name = weather_current.timezone
    elif air_current is not None:
        timezone_name = air_current.timezone
    elif weather_hourly:
        timezone_name = weather_hourly[0].timezone
    elif air_hourly:
        timezone_name = air_hourly[0].timezone

    current = None
    if weather_current is not None or air_current is not None:
        current = merge_points(
            weather_current,
            air_current,
            fallback_lat=lat,
            fallback_lon=lon,
            fallback_timezone=timezone_name,
            fetched_at=fetched_at,
            kind=EnvironmentalDataKind.OBSERVED,
        )

    hourly = merge_hourly(
        weather_hourly,
        air_hourly,
        lat=lat,
        lon=lon,
        timezone_name=timezone_name,
        fetched_at=fetched_at,
    )
    quality, missing = classify_forecast(hourly)
    sources = []
    if weather_error is None:
        sources.append(weather_provider.name)
    if air_error is None:
        sources.append(air_provider.name)

    if weather_error is not None and air_error is not None and current is None and not hourly:
        logger.info(
            "forecast_fetch_failed latency_ms=%s hours_returned=0 quality=unavailable",
            latency_ms,
        )
        raise RuntimeError("Environmental forecast unavailable")

    logger.info(
        "forecast_fetch_succeeded provider=%s hours_returned=%s quality=%s latency_ms=%s missing=%s",
        ",".join(sources) or "none",
        len(hourly),
        quality.value,
        latency_ms,
        ",".join(missing) or "none",
    )
    if quality == ForecastQuality.PARTIAL:
        logger.info(
            "forecast_partial_data hours_returned=%s missing=%s",
            len(hourly),
            ",".join(missing) or "none",
        )

    return EnvironmentalForecast(
        current=current,
        hourly=hourly,
        timezone=timezone_name,
        lat=lat,
        lon=lon,
        generated_at=fetched_at,
        fetched_at=fetched_at,
        freshness=ForecastFreshness.LIVE,
        quality=quality,
        sources=sources,
        missing_metrics=missing,
        provider_summary=f"{','.join(sources)}:{quality.value}:{len(hourly)}h",
    )


def _clip_upcoming(
    forecast: EnvironmentalForecast,
    hours: int,
    reference_now: datetime | None,
) -> EnvironmentalForecast:
    """Drop fully elapsed hours so planners never present yesterday morning as 'the day'."""
    clipped = upcoming_points(forecast.hourly, hours, now=reference_now)
    return forecast.model_copy(update={"hourly": clipped})


def get_forecast(
    lat: float,
    lon: float,
    *,
    hours: int = 48,
    force_refresh: bool = False,
    reference_now: datetime | None = None,
) -> EnvironmentalForecast:
    hours = max(24, min(48, hours))
    # Fetch a same-day buffer so mid-afternoon still yields a full upcoming window.
    fetch_hours = min(72, hours + 24)
    ttl = settings.environment_cache_ttl_seconds
    logger.info("forecast_fetch_started hours=%s force_refresh=%s", hours, str(force_refresh).lower())

    if not force_refresh:
        cached = forecast_cache.get(lat, lon, hours, ttl, allow_stale=False)
        if cached is not None:
            forecast, freshness, age = cached
            labeled = _clip_upcoming(_label_cached(forecast, freshness, age), hours, reference_now)
            logger.info(
                "forecast_cache_used freshness=%s hours_returned=%s cache_age_seconds=%s",
                freshness.value,
                len(labeled.hourly),
                age,
            )
            return labeled

    try:
        live = _LIVE_FORECAST_FLIGHT.do(
            f"{round(lat, 2)}:{round(lon, 2)}:{fetch_hours}",
            lambda: _fetch_live(lat, lon, fetch_hours),
        )
        forecast_cache.put(lat, lon, hours, live)
        return _clip_upcoming(live, hours, reference_now)
    except Exception:
        stale = forecast_cache.get(lat, lon, hours, ttl, allow_stale=True)
        if stale is not None:
            forecast, freshness, age = stale
            if not settings.environment_allow_sample_fallback and freshness == ForecastFreshness.STALE:
                labeled = _clip_upcoming(_label_cached(forecast, freshness, age), hours, reference_now)
                logger.info(
                    "forecast_cache_used freshness=stale hours_returned=%s cache_age_seconds=%s",
                    len(labeled.hourly),
                    age,
                )
                return labeled
            if freshness == ForecastFreshness.CACHED:
                return _clip_upcoming(_label_cached(forecast, freshness, age), hours, reference_now)
        raise
