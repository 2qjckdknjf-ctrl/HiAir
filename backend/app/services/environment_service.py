from datetime import UTC, datetime

import httpx

from app.core.settings import settings
from app.models.risk import EnvironmentSnapshot


def build_mock_snapshot(lat: float, lon: float) -> EnvironmentSnapshot:
    # Deterministic mock profile for local development.
    now = datetime.now(UTC)
    base_temp = 24 + (now.hour % 10)
    return EnvironmentSnapshot(
        temperature_c=float(base_temp),
        humidity_percent=float(40 + (abs(int(lat * 10)) % 35)),
        aqi=45 + (abs(int(lon * 10)) % 140),
        pm25=float(8 + (abs(int(lat * lon)) % 50)),
        ozone=float(50 + (now.hour * 2 % 75)),
        source="mock",
    )


def _fetch_openweather(lat: float, lon: float) -> tuple[float, float]:
    if not settings.weather_api_key:
        raise ValueError("WEATHER_API_KEY is missing")

    url = "https://api.openweathermap.org/data/2.5/weather"
    params = {"lat": lat, "lon": lon, "appid": settings.weather_api_key, "units": "metric"}
    with httpx.Client(timeout=10.0) as client:
        response = client.get(url, params=params)
        response.raise_for_status()
        payload = response.json()

    return float(payload["main"]["temp"]), float(payload["main"]["humidity"])


def _fetch_openmeteo_weather(lat: float, lon: float) -> tuple[float, float]:
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": lat,
        "longitude": lon,
        "current": "temperature_2m,relative_humidity_2m",
    }
    with httpx.Client(timeout=10.0) as client:
        response = client.get(url, params=params)
        response.raise_for_status()
        payload = response.json()
    current = payload.get("current", {})
    return float(current.get("temperature_2m", 0.0)), float(current.get("relative_humidity_2m", 0.0))


def _fetch_waqi(lat: float, lon: float) -> tuple[int, float, float]:
    if not settings.aqi_api_key:
        raise ValueError("AQI_API_KEY is missing")

    url = f"https://api.waqi.info/feed/geo:{lat};{lon}/"
    params = {"token": settings.aqi_api_key}
    with httpx.Client(timeout=10.0) as client:
        response = client.get(url, params=params)
        response.raise_for_status()
        payload = response.json()

    data = payload.get("data", {})
    aqi = int(data.get("aqi", 0))
    iaqi = data.get("iaqi", {})
    pm25 = float(iaqi.get("pm25", {}).get("v", 0.0))
    ozone = float(iaqi.get("o3", {}).get("v", 0.0))
    return aqi, pm25, ozone


def _fetch_openmeteo_aqi(lat: float, lon: float) -> tuple[int, float, float]:
    url = "https://air-quality-api.open-meteo.com/v1/air-quality"
    params = {
        "latitude": lat,
        "longitude": lon,
        "current": "us_aqi,pm2_5,ozone",
    }
    with httpx.Client(timeout=10.0) as client:
        response = client.get(url, params=params)
        response.raise_for_status()
        payload = response.json()
    current = payload.get("current", {})
    aqi = int(float(current.get("us_aqi", 0.0)))
    pm25 = float(current.get("pm2_5", 0.0))
    ozone = float(current.get("ozone", 0.0))
    return aqi, pm25, ozone


def fetch_live_snapshot(lat: float, lon: float) -> EnvironmentSnapshot:
    weather_provider = settings.weather_api_provider.lower()
    aqi_provider = settings.aqi_api_provider.lower()

    if weather_provider == "openweathermap":
        temperature_c, humidity_percent = _fetch_openweather(lat, lon)
    elif weather_provider == "openmeteo":
        temperature_c, humidity_percent = _fetch_openmeteo_weather(lat, lon)
    else:
        raise ValueError(f"Unsupported weather provider: {settings.weather_api_provider}")

    if aqi_provider == "waqi":
        aqi, pm25, ozone = _fetch_waqi(lat, lon)
    elif aqi_provider == "openmeteo":
        aqi, pm25, ozone = _fetch_openmeteo_aqi(lat, lon)
    else:
        raise ValueError(f"Unsupported AQI provider: {settings.aqi_api_provider}")

    return EnvironmentSnapshot(
        temperature_c=temperature_c,
        humidity_percent=humidity_percent,
        aqi=aqi,
        pm25=pm25,
        ozone=ozone,
        source="live",
    )
