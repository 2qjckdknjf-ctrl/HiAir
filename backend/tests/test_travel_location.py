"""Unit tests for travel location override helper."""

from app.models.air import ProfileType, UserProfileContext
from app.models.places import PlaceType, SavedPlaceCreateRequest
from app.services.travel_location import apply_travel_location_override
import app.services.places_repository as places_repository
import app.services.travel_repository as travel_repository


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


def _profile() -> UserProfileContext:
    return UserProfileContext(
        profile_id="p1",
        user_id="user-1",
        profile_type=ProfileType.ADULT_DEFAULT,
        home_lat=55.75,
        home_lon=37.62,
        timezone="Europe/Moscow",
        location_name="Moscow",
    )


def test_travel_override_replaces_home_coords() -> None:
    place = places_repository.create_place(
        user_id="user-1",
        payload=SavedPlaceCreateRequest(
            name="Trip",
            placeType=PlaceType.VACATION,
            lat=41.39,
            lon=2.17,
            timezone="Europe/Madrid",
        ),
    )
    travel_repository.start_travel_session("user-1", place_id=place.id, until=None)
    overridden = apply_travel_location_override("user-1", _profile())
    assert overridden.home_lat == 41.39
    assert overridden.home_lon == 2.17
    assert overridden.timezone == "Europe/Madrid"
    assert overridden.location_name == "Trip"


def test_no_travel_keeps_home() -> None:
    profile = _profile()
    same = apply_travel_location_override("user-1", profile)
    assert same.home_lat == 55.75
    assert same.home_lon == 37.62
