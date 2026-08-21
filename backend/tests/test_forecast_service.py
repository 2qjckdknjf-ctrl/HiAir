from datetime import datetime

from app.services.forecast.cache import forecast_cache
from app.services.forecast.merge import merge_hourly
from app.services.forecast.openmeteo import OpenMeteoAirQualityProvider, OpenMeteoWeatherProvider
from app.services.forecast.service import get_forecast
from tests.forecast_fixtures import barcelona_summer_payloads, openmeteo_weather_payload


def test_merge_hourly_aligns_on_utc_hour() -> None:
    weather_payload, air_payload = barcelona_summer_payloads()
    weather = OpenMeteoWeatherProvider(fetcher=lambda url, params: weather_payload)
    air = OpenMeteoAirQualityProvider(fetcher=lambda url, params: air_payload)
    merged = merge_hourly(
        weather.get_hourly(41.39, 2.17, 24),
        air.get_hourly(41.39, 2.17, 24),
        lat=41.39,
        lon=2.17,
        timezone_name="Europe/Madrid",
        fetched_at="2026-07-15T00:00:00+00:00",
    )
    assert len(merged) == 24
    noon = merged[12]
    assert noon.temperature_c == 30
    assert noon.aqi == 45
    assert noon.uv_index == 10
    assert noon.pm10_ugm3 is not None


def test_get_forecast_uses_configured_openmeteo_fixtures(monkeypatch) -> None:
    weather_payload, air_payload = barcelona_summer_payloads()

    def fetcher(url: str, params: dict) -> dict:
        if "air-quality" in url:
            return air_payload
        return weather_payload

    monkeypatch.setattr(
        "app.services.forecast.service.OpenMeteoWeatherProvider",
        lambda: OpenMeteoWeatherProvider(fetcher=fetcher),
    )
    monkeypatch.setattr(
        "app.services.forecast.service.OpenMeteoAirQualityProvider",
        lambda: OpenMeteoAirQualityProvider(fetcher=fetcher),
    )
    forecast_cache.clear()
    result = get_forecast(41.39, 2.17, hours=24, force_refresh=True)
    assert result.quality.value in ("complete", "partial")
    assert result.freshness.value == "live"
    assert len(result.hourly) == 24
    assert result.timezone == "Europe/Madrid"
    assert result.current is not None
    assert result.current.temperature_c == 24
    assert result.hourly[0].timestamp.endswith("+02:00")
    cached = get_forecast(41.39, 2.17, hours=24, force_refresh=False)
    assert cached.freshness.value == "cached"


def test_partial_when_air_hourly_missing(monkeypatch) -> None:
    start = datetime(2026, 8, 1, 0, 0)
    weather_payload = openmeteo_weather_payload(
        timezone_name="Asia/Dubai",
        start=start,
        hours=24,
        temperatures=[38.0] * 24,
        humidity=[70.0] * 24,
        uv=[9.0] * 24,
        wind=[3.0] * 24,
    )

    monkeypatch.setattr(
        "app.services.forecast.service.OpenMeteoWeatherProvider",
        lambda: OpenMeteoWeatherProvider(fetcher=lambda url, params: weather_payload),
    )
    monkeypatch.setattr(
        "app.services.forecast.service.OpenMeteoAirQualityProvider",
        lambda: OpenMeteoAirQualityProvider(fetcher=lambda url, params: (_ for _ in ()).throw(RuntimeError("down"))),
    )
    forecast_cache.clear()
    result = get_forecast(25.2, 55.27, hours=24, force_refresh=True)
    assert result.quality.value in ("partial", "unavailable")
    assert result.hourly
    assert result.hourly[0].aqi is None
    assert "aqi" in result.missing_metrics or result.quality.value == "unavailable"
