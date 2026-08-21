from datetime import datetime

from app.services.forecast.http import missing_metrics_for
from app.services.forecast.mapping import forecast_point_to_environmental
from app.services.forecast.openmeteo import OpenMeteoAirQualityProvider, OpenMeteoWeatherProvider
from app.services.forecast.openweather import OpenWeatherProvider
from app.services.forecast.waqi import WaqiAirQualityProvider
from tests.forecast_fixtures import barcelona_summer_payloads, openmeteo_air_payload, openmeteo_weather_payload


def test_openmeteo_weather_normalizes_units_and_provenance() -> None:
    weather_payload, _ = barcelona_summer_payloads()

    def fetcher(url: str, params: dict) -> dict:
        assert params["wind_speed_unit"] == "ms"
        assert params["timezone"] == "auto"
        return weather_payload

    provider = OpenMeteoWeatherProvider(fetcher=fetcher)
    current = provider.get_current(41.39, 2.17)
    hourly = provider.get_hourly(41.39, 2.17, hours=24)
    assert current.temperature_c == 24
    assert current.wind_speed_mps == 1.2
    assert current.uv_index == 0
    assert current.provenance is not None
    assert current.provenance.provider == "openmeteo_weather"
    assert current.timezone == "Europe/Madrid"
    assert current.timestamp.endswith("+02:00")
    assert len(hourly) == 24
    assert hourly[12].uv_index == 10
    assert hourly[0].provenance is not None
    assert hourly[0].provenance.kind.value == "forecast"


def test_openmeteo_air_keeps_null_metrics() -> None:
    start = datetime(2026, 7, 15, 0, 0)
    payload = openmeteo_air_payload(
        timezone_name="Europe/Madrid",
        start=start,
        hours=2,
        aqi=[40, 50],
        pm25=[8.0, 9.0],
        pm10=[None, 20.0],  # type: ignore[list-item]
        ozone=[30.0, 31.0],
        no2=[None, None],  # type: ignore[list-item]
    )
    payload["hourly"]["pm10"] = [None, 20.0]
    payload["hourly"]["nitrogen_dioxide"] = [None, None]
    payload["current"]["pm10"] = None
    payload["current"]["nitrogen_dioxide"] = None

    provider = OpenMeteoAirQualityProvider(fetcher=lambda url, params: payload)
    current = provider.get_current(41.39, 2.17)
    hourly = provider.get_hourly(41.39, 2.17, hours=2)
    assert current.pm10_ugm3 is None
    assert "pm10_ugm3" in current.missing_metrics
    assert hourly[0].no2_ugm3 is None
    assert hourly[1].pm10_ugm3 == 20.0


def test_openweather_hourly_is_empty_not_interpolated() -> None:
    payload = {
        "dt": 1750000000,
        "main": {"temp": 33.0, "feels_like": 36.0, "humidity": 20.0},
        "wind": {"speed": 4.1, "gust": 6.0},
    }
    provider = OpenWeatherProvider(fetcher=lambda url, params: payload, api_key="test")
    current = provider.get_current(33.45, -112.07)
    assert current.temperature_c == 33.0
    assert current.wind_speed_mps == 4.1
    assert current.uv_index is None
    assert provider.get_hourly(33.45, -112.07, hours=48) == []


def test_waqi_uses_direct_pm10_when_present_and_has_no_hourly() -> None:
    payload = {
        "data": {
            "aqi": 87,
            "iaqi": {
                "pm25": {"v": 22.0},
                "pm10": {"v": 41.0},
                "o3": {"v": 18.0},
            },
            "time": {"iso": "2026-07-15T10:00:00+02:00"},
        }
    }
    provider = WaqiAirQualityProvider(fetcher=lambda url, params: payload, api_key="test")
    current = provider.get_current(41.39, 2.17)
    assert current.pm10_ugm3 == 41.0
    assert current.pm25_ugm3 == 22.0
    assert current.uv_index is None
    assert provider.get_hourly(41.39, 2.17) == []


def test_mapping_does_not_fill_missing_air_with_zero() -> None:
    weather_payload, _ = barcelona_summer_payloads()
    provider = OpenMeteoWeatherProvider(fetcher=lambda url, params: weather_payload)
    point = provider.get_current(41.39, 2.17)
    mapped = forecast_point_to_environmental(point)
    assert mapped is not None
    assert mapped.aqi is None
    assert mapped.pm25 is None
    assert mapped.uv == 0


def test_missing_metrics_helper() -> None:
    assert missing_metrics_for({"temperature_c": 1, "uv_index": None}, ("temperature_c", "uv_index")) == [
        "uv_index"
    ]
