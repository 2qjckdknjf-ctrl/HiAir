"""Briefing due-dispatch re-resolves timezone under active travel."""

from __future__ import annotations

from datetime import UTC, datetime
from unittest.mock import patch

from app.models.air import ProfileType, UserProfileContext
from app.models.places import PlaceType, SavedPlaceCreateRequest
import app.services.places_repository as places_repository
import app.services.travel_repository as travel_repository
from app.services.briefing_service import get_due_briefings


def setup_function() -> None:
    places_repository.force_memory_store(True)
    places_repository.reset_store()
    travel_repository.force_memory_store(True)
    travel_repository.reset_store()


def teardown_function() -> None:
    travel_repository.reset_store()
    travel_repository.force_memory_store(False)
    places_repository.reset_store()
    places_repository.force_memory_store(False)


def test_dispatch_timezone_follows_travel() -> None:
    place = places_repository.create_place(
        user_id="user-1",
        payload=SavedPlaceCreateRequest(
            name="NYC",
            placeType=PlaceType.VACATION,
            lat=40.7,
            lon=-74.0,
            timezone="America/New_York",
        ),
    )
    travel_repository.start_travel_session("user-1", place_id=place.id, until=None)

    profile = UserProfileContext(
        profile_id="p1",
        user_id="user-1",
        profile_type=ProfileType.ADULT_DEFAULT,
        home_lat=55.75,
        home_lon=37.62,
        timezone="Europe/Moscow",
        location_name="Moscow",
    )
    schedules = [
        {
            "user_id": "user-1",
            "timezone": "Europe/Moscow",
            "local_time": "07:30",
            "last_sent_at": None,
        }
    ]

    with patch(
        "app.services.briefing_service.briefing_repository.list_enabled_schedules",
        return_value=schedules,
    ):
        with patch(
            "app.services.briefing_service.briefing_repository.get_user_profile_ids",
            return_value=["p1"],
        ):
            with patch(
                "app.services.briefing_service.air_repository.get_profile_context",
                return_value=profile,
            ):
                with patch(
                    "app.services.briefing_service._is_due",
                    return_value=True,
                ) as is_due:
                    due = get_due_briefings(now_utc=datetime(2026, 6, 15, 12, 0, tzinfo=UTC))

    assert due[0]["timezone"] == "America/New_York"
    assert is_due.call_args.kwargs["timezone_name"] == "America/New_York"
