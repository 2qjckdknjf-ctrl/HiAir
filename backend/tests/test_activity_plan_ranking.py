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


def _env(
    ts: str,
    *,
    feels_like: float,
    uv: float | None = 2.0,
) -> EnvironmentalInput:
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
        uv=uv,
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


def test_merged_window_confidence_uses_weakest_hour() -> None:
    complete = _env("2026-09-08T07:00:00+02:00", feels_like=22.0)
    partial = _env("2026-09-08T08:00:00+02:00", feels_like=22.0, uv=None)

    plan = activity_plan_engine.build_activity_plan(
        profile=_profile(),
        environment=complete,
        hourly_points=[complete, partial],
        activity=ActivityType.RUNNING,
        duration_minutes=90,
        intensity=ActivityIntensity.HIGH,
    )

    assert len(plan.windows) == 1
    assert plan.windows[0].tier.value == "best"
    assert plan.windows[0].confidence == 0.85


def test_missing_hour_cannot_be_used_as_continuous_activity():
    points = [_env('2026-08-21T07:00:00+02:00', feels_like=23),
              _env('2026-08-21T09:00:00+02:00', feels_like=23)]
    plan = activity_plan_engine.build_activity_plan(profile=_profile(), environment=points[0],
        hourly_points=points, activity=ActivityType.RUNNING, duration_minutes=90)
    assert plan.recommendedStart is None
    assert len(plan.windows) == 2


def test_latest_start_keeps_following_hour_for_duration_validation():
    points = [_env('2026-08-21T07:00:00+02:00', feels_like=23),
              _env('2026-08-21T08:00:00+02:00', feels_like=23)]
    plan = activity_plan_engine.build_activity_plan(profile=_profile(), environment=points[0],
        hourly_points=list(reversed(points)), activity=ActivityType.RUNNING, duration_minutes=90,
        earliest_start=points[0].timestamp, latest_start=points[0].timestamp)
    assert plan.recommendedStart == points[0].timestamp
    assert plan.recommendedWindow.end == "2026-08-21T08:30:00+02:00"


def test_action_bounds_reject_invalid_naive_and_reversed_dates():
    import pytest
    from pydantic import ValidationError
    from app.models.activity_plan import ActivityPlanRequest
    for bounds in [dict(earliestStart='not-a-date'), dict(earliestStart='2026-08-21T07:00:00'),
                   dict(earliestStart='2026-08-21T09:00:00Z', latestStart='2026-08-21T08:00:00Z')]:
        with pytest.raises(ValidationError):
            ActivityPlanRequest(profileId='p', activity='walking', **bounds)
