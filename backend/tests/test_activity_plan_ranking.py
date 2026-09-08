"""Regression tests for deterministic HiAir Action best-time ranking."""

from app.models.activity_plan import ActivityIntensity, ActivityType
from app.models.air import EnvironmentalInput, ProfileType, UserProfileContext
from app.services import activity_plan_engine


def _profile() -> UserProfileContext:
    return UserProfileContext(
        profile_id="profile-ranking",
        user_id="user-ranking",
        profile_type=ProfileType.ADULT_DEFAULT,
        home_lat=41.39,
        home_lon=2.17,
        timezone="Europe/Madrid",
    )


def _env(ts: str, *, feels_like: float) -> EnvironmentalInput:
    return EnvironmentalInput(
        lat=41.39,
        lon=2.17,
        temperature=feels_like - 1.0,
        feels_like=feels_like,
        humidity=50.0,
        aqi=35,
        pm25=8.0,
        pm10=12.0,
        ozone=35.0,
        uv=2.0,
        wind_speed=2.0,
        source="openmeteo",
        timestamp=ts,
        timezone="Europe/Madrid",
    )


def test_later_stronger_best_candidate_beats_first_best_candidate() -> None:
    early = _env("2026-09-08T07:00:00+02:00", feels_like=27.0)
    later = _env("2026-09-08T08:00:00+02:00", feels_like=22.0)

    plan = activity_plan_engine.build_activity_plan(
        profile=_profile(),
        environment=early,
        hourly_points=[early, later],
        activity=ActivityType.RUNNING,
        duration_minutes=45,
        intensity=ActivityIntensity.HIGH,
    )

    assert plan.hourly[0].tier.value == "best"
    assert plan.hourly[1].tier.value == "best"
    assert plan.hourly[1].score > plan.hourly[0].score
    assert plan.recommendedStart == later.timestamp


def test_equal_best_candidates_keep_earlier_start_as_stable_tie_break() -> None:
    early = _env("2026-09-08T07:00:00+02:00", feels_like=22.0)
    later = _env("2026-09-08T08:00:00+02:00", feels_like=22.0)

    plan = activity_plan_engine.build_activity_plan(
        profile=_profile(),
        environment=early,
        hourly_points=[early, later],
        activity=ActivityType.RUNNING,
        duration_minutes=45,
        intensity=ActivityIntensity.HIGH,
    )

    assert plan.hourly[0].score == plan.hourly[1].score
    assert plan.recommendedStart == early.timestamp
