"""API tests for HiAir 1.5 travel mode."""

from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

import app.api.deps as deps
from app.main import app
import app.services.places_repository as places_repository
import app.services.travel_repository as travel_repository
from app.models.places import PlaceType, SavedPlaceCreateRequest

client = TestClient(app)


def _auth() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


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


def _create_place(user_id: str = "user-1") -> str:
    app.dependency_overrides[deps.get_current_user_id] = lambda: user_id
    place = places_repository.create_place(
        user_id=user_id,
        payload=SavedPlaceCreateRequest(
            name="Barcelona trip",
            placeType=PlaceType.VACATION,
            lat=41.39,
            lon=2.17,
            timezone="Europe/Madrid",
        ),
    )
    return place.id


def test_start_and_get_travel_session() -> None:
    place_id = _create_place()
    try:
        start = client.post(
            "/api/travel/session",
            headers=_auth(),
            json={"placeId": place_id},
        )
        assert start.status_code == 200, start.text
        body = start.json()
        assert body["active"] is True
        assert body["placeId"] == place_id
        assert body["lat"] == 41.39
        assert body["source"] == "travel"

        current = client.get("/api/travel/session", headers=_auth())
        assert current.status_code == 200
        assert current.json()["active"] is True
    finally:
        app.dependency_overrides.clear()


def test_clear_travel_session() -> None:
    place_id = _create_place()
    try:
        client.post("/api/travel/session", headers=_auth(), json={"placeId": place_id})
        cleared = client.delete("/api/travel/session", headers=_auth())
        assert cleared.status_code == 200
        assert cleared.json()["active"] is False
        assert cleared.json()["source"] == "home"
    finally:
        app.dependency_overrides.clear()


def test_travel_rejects_foreign_place() -> None:
    place_id = _create_place("user-a")
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-b"
    try:
        response = client.post(
            "/api/travel/session",
            headers=_auth(),
            json={"placeId": place_id},
        )
        assert response.status_code == 404
    finally:
        app.dependency_overrides.clear()


def test_expired_travel_session_is_inactive() -> None:
    place_id = _create_place()
    past = (datetime.now(tz=UTC) - timedelta(hours=1)).isoformat()
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    try:
        response = client.post(
            "/api/travel/session",
            headers=_auth(),
            json={"placeId": place_id, "until": past},
        )
        assert response.status_code == 404
    finally:
        app.dependency_overrides.clear()
