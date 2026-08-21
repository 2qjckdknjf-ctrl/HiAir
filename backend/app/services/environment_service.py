from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from typing import Any

import httpx

from app.core.settings import settings
from app.models.risk import EnvironmentSnapshot


def build_sample_snapshot(lat: float, lon: float) -> EnvironmentSnapshot:
    """Deterministic fallback when live providers and cache are unavailable."""
    now = datetime.utcnow()
    base_temp = 24 + (now.hour % 10)
    return EnvironmentSnapshot(
        temperature_c=float(base_temp),
        humidity_percent=float(40 + (abs(int(lat * 10)) % 35)),
        aqi=45 + (abs(int(lon * 10)) % 140),
        pm25=float(8 + (abs(int(lat * lon)) % 50)),
        ozone=float(50 + (now.hour * 2 % 75)),
        source="sample",
    )


def build_mock_snapshot(lat: float, lon: float) -> EnvironmentSnapshot:
    """Deprecated alias — use build_sample_snapshot."""
    return build_sample_snapshot(lat, lon)


def _optional_float(value: Any) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _iaqi(iaqi: dict[str, Any], key: str) -> float | None:
    entry = iaqi.get(key)
    if isinstance(entry, dict):
        return _optional_float(entry.get("v"))
    return None


def _fetch_openweather(lat: float, lon: float) -> dict[str, Any]:
    if not settings.weather_api_key:
        raise ValueError("WEATHER_API_KEY is missing")

    url = "https://api.openweathermap.org/data/2.5/weather"
    params = {"lat": lat, "lon": lon, "appid": settings.weather_api_key, "units": "metric"}
    with httpx.Client(timeout=10.0) as client:
        response = client.get(url, params=params)
        response.raise_for_status()
        payload = response.json()
    main = payload.get("main") or {}
    wind = payload.get("wind") or {}
    return {
        "temperature_c": float(main["temp"]),
        "humidity_percent": float(main["humidity"]),
        "feels_like": _optional_float(main.get("feels_like")),
        "wind_speed": _optional_float(wind.get("speed")),
        "uv": None,
    }


def _fetch_openmeteo_weather(lat: float, lon: float) -> dict[str, Any]:
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": lat,
        "longitude": lon,
        "current": "temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,uv_index",
        "wind_speed_unit": "ms",
        "timezone": "auto",
    }
    with httpx.Client(timeout=10.0) as client:
        response = client.get(url, params=params)
        response.raise_for_status()
        payload = response.json()
    current = payload.get("current") or {}
    temperature = _optional_float(current.get("temperature_2m"))
    humidity = _optional_float(current.get("relative_humidity_2m"))
    if temperature is None or humidity is None:
        raise ValueError("Open-Meteo weather returned incomplete current conditions")
    return {
        "temperature_c": temperature,
        "humidity_percent": humidity,
        "feels_like": _optional_float(current.get("apparent_temperature")),
        "wind_speed": _optional_float(current.get("wind_speed_10m")),
        "uv": _optional_float(current.get("uv_index")),
        "timezone": payload.get("timezone"),
    }


def _fetch_waqi(lat: float, lon: float) -> dict[str, Any]:
    if not settings.aqi_api_key:
        raise ValueError("AQI_API_KEY is missing")

    url = f"https://api.waqi.info/feed/geo:{lat};{lon}/"
    params = {"token": settings.aqi_api_key}
    with httpx.Client(timeout=10.0) as client:
        response = client.get(url, params=params)
        response.raise_for_status()
        payload = response.json()

    data = payload.get("data") or {}
    iaqi = data.get("iaqi") or {}
    aqi_value = data.get("aqi")
    aqi = int(aqi_value) if aqi_value is not None and str(aqi_value).strip() != "" else None
    pm25 = _iaqi(iaqi, "pm25")
    ozone = _iaqi(iaqi, "o3")
    if aqi is None and pm25 is None and ozone is None:
        raise ValueError("WAQI returned no air metrics")
    return {
        "aqi": aqi,
        "pm25": pm25,
        "ozone": ozone,
        "pm10": _iaqi(iaqi, "pm10"),
    }


def _fetch_openmeteo_aqi(lat: float, lon: float) -> dict[str, Any]:
    url = "https://air-quality-api.open-meteo.com/v1/air-quality"
    params = {
        "latitude": lat,
        "longitude": lon,
        "current": "us_aqi,pm2_5,pm10,ozone",
        "timezone": "auto",
    }
    with httpx.Client(timeout=10.0) as client:
        response = client.get(url, params=params)
        response.raise_for_status()
        payload = response.json()
    current = payload.get("current") or {}
    aqi = _optional_float(current.get("us_aqi"))
    pm25 = _optional_float(current.get("pm2_5"))
    ozone = _optional_float(current.get("ozone"))
    if aqi is None and pm25 is None and ozone is None:
        raise ValueError("Open-Meteo AQI returned no air metrics")
    return {
        "aqi": int(aqi) if aqi is not None else None,
        "pm25": pm25,
        "ozone": ozone,
        "pm10": _optional_float(current.get("pm10")),
    }


def fetch_live_snapshot(lat: float, lon: float) -> EnvironmentSnapshot:
    weather_provider = settings.weather_api_provider.lower()
    aqi_provider = settings.aqi_api_provider.lower()

    def _weather() -> dict[str, Any]:
        if weather_provider == "openweathermap":
            return _fetch_openweather(lat, lon)
        if weather_provider == "openmeteo":
            return _fetch_openmeteo_weather(lat, lon)
        raise ValueError(f"Unsupported weather provider: {settings.weather_api_provider}")

    def _aqi() -> dict[str, Any]:
        if aqi_provider == "waqi":
            return _fetch_waqi(lat, lon)
        if aqi_provider == "openmeteo":
            return _fetch_openmeteo_aqi(lat, lon)
        raise ValueError(f"Unsupported AQI provider: {settings.aqi_api_provider}")

    with ThreadPoolExecutor(max_workers=2) as pool:
        weather_future = pool.submit(_weather)
        aqi_future = pool.submit(_aqi)
        weather = weather_future.result()
        air = aqi_future.result()

    return EnvironmentSnapshot(
        temperature_c=float(weather["temperature_c"]),
        humidity_percent=float(weather["humidity_percent"]),
        aqi=air.get("aqi"),
        pm25=air.get("pm25"),
        ozone=air.get("ozone"),
        source="live",
        pm10=air.get("pm10"),
        uv=weather.get("uv"),
        wind_speed=weather.get("wind_speed"),
        feels_like=weather.get("feels_like"),
        timezone=weather.get("timezone"),
    )
