"""Legacy /planner/daily honors active travel coordinates."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

import app.api.deps as deps
from app.main import app
from app.models.places import PlaceType, SavedPlaceCreateRequest
import app.services.places_repository as places_repository
import app.services.travel_repository as travel_repository


client = TestClient(app)


def setup_function() -> None:
    places_repository.force_memory_store(True)
    places_repository.reset_store()
    travel_repository.force_memory_store(True)
    travel_repository.reset_store()


def teardown_function() -> None:
    app.dependency_overrides.clear()
    travel_repository.reset_store()
    travel_repository.force_memory_store(False)
    places_repository.reset_store()
    places_repository.force_memory_store(False)


def _auth() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


@patch("app.api.planner.entitlement_service.require_feature", return_value=None)
@patch("app.api.planner.get_forecast")
@patch("app.api.planner.air_environment_service.load_environment", return_value=MagicMock())
def test_daily_planner_uses_travel_coords(
    _load_env,
    get_forecast,
    _ent,
) -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    place = places_repository.create_place(
        user_id="user-1",
        payload=SavedPlaceCreateRequest(
            name="Barcelona",
            placeType=PlaceType.VACATION,
            lat=41.39,
            lon=2.17,
            timezone="Europe/Madrid",
        ),
    )
    travel_repository.start_travel_session("user-1", place_id=place.id, until=None)

    get_forecast.return_value = MagicMock(
        timezone="Europe/Madrid",
        quality=MagicMock(value="ok"),
        freshness=MagicMock(value="live"),
        sources=["openmeteo"],
        missing_metrics=None,
    )

    with patch("app.api.planner.forecast_to_hourly_inputs", return_value=[]):
        with patch(
            "app.api.planner.air_risk_engine._build_safe_windows_from_hourly",
            return_value=[],
        ):
            response = client.get(
                "/api/planner/daily?lat=55.75&lon=37.62",
                headers=_auth(),
            )

    assert response.status_code == 200
    body = response.json()
    assert body["base_lat"] == 41.39
    assert body["base_lon"] == 2.17
    assert get_forecast.call_args.args[0] == 41.39
    assert get_forecast.call_args.args[1] == 2.17
