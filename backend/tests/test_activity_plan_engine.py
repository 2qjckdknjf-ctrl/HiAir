"""HiAir 1.2 activity planner engine tests."""

from app.models.activity_plan import ActivityIntensity, ActivityType, ActivityWindowTier
from app.models.air import EnvironmentalInput, ProfileType, UserProfileContext
from app.services.activity_plan_engine import build_activity_plan, catalog, score_hour


def _profile(profile_type: ProfileType = ProfileType.ADULT_DEFAULT) -> UserProfileContext:
    return UserProfileContext(
        profile_id="profile-1",
        user_id="user-1",
        profile_type=profile_type,
        timezone="Europe/Madrid",
        home_lat=41.39,
        home_lon=2.17,
    )


def _env(
    hour: str,
    *,
    feels_like: float = 24.0,
    aqi: int | None = 40,
    pm25: float | None = 10.0,
    ozone: float | None = 40.0,
    uv: float | None = 4.0,
) -> EnvironmentalInput:
    return EnvironmentalInput(
        lat=41.39,
        lon=2.17,
        temperature=feels_like - 1,
        feels_like=feels_like,
        humidity=50.0,
        aqi=aqi,
        pm25=pm25,
        pm10=15.0,
        ozone=ozone,
        uv=uv,
        wind_speed=3.0,
        source="openmeteo",
        timestamp=hour,
        timezone="Europe/Madrid",
    )


def test_catalog_covers_master_plan_activities() -> None:
    activities = {item.activity for item in catalog()}
    assert ActivityType.RUNNING in activities
    assert ActivityType.VENTILATION in activities
    assert len(activities) == 10


def test_running_best_when_cool_and_air_known() -> None:
    result = score_hour(
        activity=ActivityType.RUNNING,
        intensity=ActivityIntensity.HIGH,
        profile=_profile(),
        environment=_env("2026-08-21T07:00:00+02:00", feels_like=24.0),
    )
    assert result.tier == ActivityWindowTier.BEST


def test_running_avoid_without_air_data() -> None:
    result = score_hour(
        activity=ActivityType.RUNNING,
        intensity=ActivityIntensity.HIGH,
        profile=_profile(),
        environment=_env(
            "2026-08-21T07:00:00+02:00",
            feels_like=22.0,
            aqi=None,
            pm25=None,
            ozone=None,
        ),
    )
    assert result.tier == ActivityWindowTier.AVOID
    assert "air_data_unavailable" in result.reasonCodes


def test_beach_avoids_extreme_uv() -> None:
    result = score_hour(
        activity=ActivityType.BEACH,
        intensity=ActivityIntensity.MODERATE,
        profile=_profile(),
        environment=_env("2026-08-21T13:00:00+02:00", feels_like=27.0, uv=11.0),
    )
    assert result.tier == ActivityWindowTier.AVOID
    assert "uv" in result.reasonCodes


def test_build_plan_recommends_best_window_start() -> None:
    cool = _env("2026-08-21T07:00:00+02:00", feels_like=23.0)
    hot = _env("2026-08-21T14:00:00+02:00", feels_like=37.0, aqi=130, pm25=40.0)
    plan = build_activity_plan(
        profile=_profile(),
        environment=cool,
        hourly_points=[cool, hot],
        activity=ActivityType.WALKING,
        duration_minutes=30,
    )
    assert plan.forecastAvailable is True
    assert plan.recommendedStart == "2026-08-21T07:00:00+02:00"
    assert plan.windows[0].tier == ActivityWindowTier.BEST
    assert plan.windows[-1].tier == ActivityWindowTier.AVOID


def test_empty_forecast_is_honest() -> None:
    now = _env("2026-08-21T07:00:00+02:00")
    plan = build_activity_plan(
        profile=_profile(),
        environment=now,
        hourly_points=[],
        activity=ActivityType.CYCLING,
    )
    assert plan.forecastAvailable is False
    assert plan.recommendedStart is None
    assert plan.windows == []
    assert plan.dataQuality == "unavailable"
