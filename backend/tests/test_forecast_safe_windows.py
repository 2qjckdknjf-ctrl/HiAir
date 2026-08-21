"""Safe windows and climate matrix must be derived from real hourly forecast points."""

from datetime import datetime

from app.models.air import EnvironmentalInput, ProfileType, RiskLevel, SafeWindowType, UserProfileContext
from app.services.air_risk_engine import build_day_plan, evaluate_risk
from app.services.forecast.mapping import forecast_point_to_environmental
from app.services.forecast.merge import merge_hourly
from app.services.forecast.openmeteo import OpenMeteoAirQualityProvider, OpenMeteoWeatherProvider
from tests.forecast_fixtures import openmeteo_air_payload, openmeteo_weather_payload


def _profile(timezone_name: str = "Europe/Madrid") -> UserProfileContext:
    return UserProfileContext(
        profile_id="profile-1",
        user_id="user-1",
        profile_type=ProfileType.ADULT_DEFAULT,
        timezone=timezone_name,
        home_lat=41.39,
        home_lon=2.17,
    )


def _hourly(
    timezone_name: str,
    lat: float,
    lon: float,
    temps: list[float],
    aqi: list[int],
    humidity: list[float] | None = None,
) -> list[EnvironmentalInput]:
    hours = len(temps)
    start = datetime(2026, 7, 15, 0, 0)
    weather = openmeteo_weather_payload(
        timezone_name=timezone_name,
        start=start,
        hours=hours,
        temperatures=temps,
        humidity=humidity or [45.0] * hours,
        uv=[5.0] * hours,
        wind=[2.0] * hours,
    )
    air = openmeteo_air_payload(
        timezone_name=timezone_name,
        start=start,
        hours=hours,
        aqi=aqi,
        pm25=[float(value) * 0.25 for value in aqi],
        pm10=[float(value) * 0.4 for value in aqi],
        ozone=[40.0] * hours,
    )
    merged = merge_hourly(
        OpenMeteoWeatherProvider(fetcher=lambda url, params: weather).get_hourly(lat, lon, hours),
        OpenMeteoAirQualityProvider(fetcher=lambda url, params: air).get_hourly(lat, lon, hours),
        lat=lat,
        lon=lon,
        timezone_name=timezone_name,
        fetched_at="2026-07-15T00:00:00+00:00",
    )
    points: list[EnvironmentalInput] = []
    for item in merged:
        mapped = forecast_point_to_environmental(item)
        if mapped is not None:
            points.append(mapped)
    return points


def test_safe_windows_merge_consecutive_low_hours() -> None:
    temps = [22.0] * 24
    aqi = [30] * 8 + [160] * 4 + [30] * 12
    hourly = _hourly("Europe/Madrid", 41.39, 2.17, temps, aqi)
    plan = build_day_plan(_profile(), hourly[0], hourly_points=hourly)
    walk = [window for window in plan.safeWindows if window.type == SafeWindowType.WALK]
    assert walk
    assert walk[0].start.endswith("+02:00")
    timestamps = [item.timestamp for item in hourly]
    assert timestamps == sorted(timestamps)


def test_climates_produce_different_risk_periods() -> None:
    barcelona = _hourly(
        "Europe/Madrid",
        41.39,
        2.17,
        [24.0] * 12 + [28.0] * 12,
        [40] * 24,
        humidity=[70.0] * 24,
    )
    phoenix = _hourly(
        "America/Phoenix",
        33.45,
        -112.07,
        [28.0] * 8 + [42.0] * 10 + [30.0] * 6,
        [50] * 24,
        humidity=[10.0] * 24,
    )
    dubai = _hourly("Asia/Dubai", 25.2, 55.27, [36.0] * 24, [80] * 24, humidity=[80.0] * 24)
    riyadh = _hourly("Asia/Riyadh", 24.71, 46.68, [42.0] * 24, [70] * 24, humidity=[12.0] * 24)
    cairo = _hourly("Africa/Cairo", 30.04, 31.24, [38.0] * 24, [180] * 24, humidity=[40.0] * 24)
    miami = _hourly("America/New_York", 25.76, -80.19, [30.0] * 24, [55] * 24, humidity=[85.0] * 24)

    barcelona_plan = build_day_plan(_profile("Europe/Madrid"), barcelona[0], hourly_points=barcelona)
    phoenix_plan = build_day_plan(_profile("America/Phoenix"), phoenix[0], hourly_points=phoenix)
    dubai_plan = build_day_plan(_profile("Asia/Dubai"), dubai[0], hourly_points=dubai)
    cairo_plan = build_day_plan(_profile("Africa/Cairo"), cairo[0], hourly_points=cairo)
    riyadh_plan = build_day_plan(_profile("Asia/Riyadh"), riyadh[0], hourly_points=riyadh)
    miami_plan = build_day_plan(_profile("America/New_York"), miami[0], hourly_points=miami)

    def high_count(plan) -> int:
        return sum(
            1 for item in plan.hourlyRisk if item.overallRisk in (RiskLevel.HIGH, RiskLevel.VERY_HIGH)
        )

    assert high_count(phoenix_plan) > high_count(barcelona_plan)
    assert high_count(dubai_plan) > high_count(barcelona_plan)
    assert high_count(cairo_plan) > high_count(barcelona_plan)
    assert barcelona_plan.hourlyRisk[0].hour.endswith("+02:00")
    assert phoenix_plan.hourlyRisk[0].hour.endswith("-07:00")
    assert dubai_plan.hourlyRisk[0].hour.endswith("+04:00")
    assert miami_plan.hourlyRisk[0].hour.endswith("-04:00")
    assert riyadh_plan.hourlyRisk[0].hour.endswith("+03:00")
    cairo_offset = cairo_plan.hourlyRisk[0].hour[-6:]
    assert cairo_offset.startswith("+")


def test_evaluate_risk_does_not_invent_windows_without_hourly() -> None:
    result = evaluate_risk(_profile(), _hourly("Europe/Madrid", 41.39, 2.17, [22.0] * 3, [30] * 3)[0])
    assert result.safeWindows == []
