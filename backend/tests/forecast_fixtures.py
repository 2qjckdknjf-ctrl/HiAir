"""Deterministic Open-Meteo-shaped fixtures for HiAir 1.1 forecast tests."""

from __future__ import annotations

from datetime import datetime, timedelta
from zoneinfo import ZoneInfo


def _hours(start: datetime, count: int) -> list[str]:
    return [(start + timedelta(hours=offset)).strftime("%Y-%m-%dT%H:%M") for offset in range(count)]


def openmeteo_weather_payload(
    *,
    timezone_name: str,
    start: datetime,
    hours: int,
    temperatures: list[float],
    humidity: list[float] | None = None,
    apparent: list[float] | None = None,
    wind: list[float] | None = None,
    uv: list[float] | None = None,
    dew: list[float] | None = None,
    gust: list[float] | None = None,
) -> dict:
    times = _hours(start, hours)
    humidity = humidity or [50.0] * hours
    apparent = apparent or temperatures
    wind = wind if wind is not None else [2.0] * hours
    uv = uv if uv is not None else [5.0] * hours
    dew = dew if dew is not None else [12.0] * hours
    gust = gust if gust is not None else [3.0] * hours
    return {
        "timezone": timezone_name,
        "utc_offset_seconds": int(start.replace(tzinfo=ZoneInfo(timezone_name)).utcoffset().total_seconds())
        if start.tzinfo is None
        else int(start.utcoffset().total_seconds() if start.utcoffset() else 0),
        "current": {
            "time": times[0],
            "temperature_2m": temperatures[0],
            "apparent_temperature": apparent[0],
            "relative_humidity_2m": humidity[0],
            "dew_point_2m": dew[0],
            "wind_speed_10m": wind[0],
            "wind_gusts_10m": gust[0],
            "uv_index": uv[0],
        },
        "hourly": {
            "time": times,
            "temperature_2m": temperatures,
            "apparent_temperature": apparent,
            "relative_humidity_2m": humidity,
            "dew_point_2m": dew,
            "wind_speed_10m": wind,
            "wind_gusts_10m": gust,
            "uv_index": uv,
        },
    }


def openmeteo_air_payload(
    *,
    timezone_name: str,
    start: datetime,
    hours: int,
    aqi: list[int],
    pm25: list[float] | None = None,
    pm10: list[float] | None = None,
    ozone: list[float] | None = None,
    no2: list[float] | None = None,
) -> dict:
    times = _hours(start, hours)
    pm25 = pm25 if pm25 is not None else [10.0] * hours
    pm10 = pm10 if pm10 is not None else [18.0] * hours
    ozone = ozone if ozone is not None else [40.0] * hours
    no2 = no2 if no2 is not None else [12.0] * hours
    return {
        "timezone": timezone_name,
        "current": {
            "time": times[0],
            "us_aqi": aqi[0],
            "pm2_5": pm25[0],
            "pm10": pm10[0],
            "ozone": ozone[0],
            "nitrogen_dioxide": no2[0],
        },
        "hourly": {
            "time": times,
            "us_aqi": aqi,
            "pm2_5": pm25,
            "pm10": pm10,
            "ozone": ozone,
            "nitrogen_dioxide": no2,
        },
    }


def barcelona_summer_payloads() -> tuple[dict, dict]:
    start = datetime(2026, 7, 15, 0, 0)
    hours = 48
    temps = [24 + (6 if 11 <= (h % 24) <= 17 else 0) for h in range(hours)]
    aqi = [45 + (40 if 8 <= (h % 24) <= 10 or 18 <= (h % 24) <= 20 else 0) for h in range(hours)]
    uv_day = [0, 0, 0, 0, 0, 1, 2, 4, 6, 8, 9, 9, 10, 9, 8, 6, 4, 2, 1, 0, 0, 0, 0, 0]
    weather = openmeteo_weather_payload(
        timezone_name="Europe/Madrid",
        start=start,
        hours=hours,
        temperatures=temps,
        humidity=[65.0] * hours,
        uv=uv_day * 2,
        wind=[1.2] * hours,
    )
    air = openmeteo_air_payload(
        timezone_name="Europe/Madrid",
        start=start,
        hours=hours,
        aqi=aqi,
        pm25=[8 + (x - 45) * 0.3 for x in aqi],
        pm10=[14 + (x - 45) * 0.4 for x in aqi],
    )
    return weather, air
