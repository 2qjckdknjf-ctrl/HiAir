"""API tests for HiAir 1.5 saved places routes."""

from fastapi.testclient import TestClient

import app.api.deps as deps
from app.main import app
import app.services.places_repository as places_repository

client = TestClient(app)


def _auth() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def setup_function() -> None:
    places_repository.force_memory_store(True)
    places_repository.reset_store()


def teardown_function() -> None:
    places_repository.reset_store()
    places_repository.force_memory_store(False)


def test_create_and_list_saved_places() -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    try:
        create_response = client.post(
            "/api/places",
            headers=_auth(),
            json={
                "name": "Home",
                "placeType": "home",
                "lat": 41.39,
                "lon": 2.17,
                "timezone": "Europe/Madrid",
            },
        )
        assert create_response.status_code == 200, create_response.text
        created = create_response.json()
        assert created["userId"] == "user-1"
        assert created["name"] == "Home"
        assert created["placeType"] == "home"
        assert created["lat"] == 41.39
        assert created["lon"] == 2.17
        assert created["timezone"] == "Europe/Madrid"
        assert created["id"]
        assert created["createdAt"]

        list_response = client.get("/api/places", headers=_auth())
        assert list_response.status_code == 200
        body = list_response.json()
        assert len(body["places"]) == 1
        assert body["places"][0]["id"] == created["id"]
    finally:
        app.dependency_overrides.clear()


def test_delete_saved_place() -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    try:
        create_response = client.post(
            "/api/places",
            headers=_auth(),
            json={
                "name": "Office",
                "placeType": "work",
                "lat": 40.42,
                "lon": -3.70,
            },
        )
        place_id = create_response.json()["id"]

        delete_response = client.delete(f"/api/places/{place_id}", headers=_auth())
        assert delete_response.status_code == 204

        list_response = client.get("/api/places", headers=_auth())
        assert list_response.json()["places"] == []
    finally:
        app.dependency_overrides.clear()


def test_delete_missing_place_returns_404() -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    try:
        response = client.delete("/api/places/missing-place-id", headers=_auth())
        assert response.status_code == 404
    finally:
        app.dependency_overrides.clear()


def test_places_are_isolated_by_user() -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-a"
    try:
        create_response = client.post(
            "/api/places",
            headers=_auth(),
            json={
                "name": "Parents",
                "placeType": "parents",
                "lat": 55.75,
                "lon": 37.62,
            },
        )
        place_id = create_response.json()["id"]
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-b"
    try:
        list_response = client.get("/api/places", headers=_auth())
        assert list_response.status_code == 200
        assert list_response.json()["places"] == []

        delete_response = client.delete(f"/api/places/{place_id}", headers=_auth())
        assert delete_response.status_code == 404
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-a"
    try:
        list_response = client.get("/api/places", headers=_auth())
        assert len(list_response.json()["places"]) == 1
    finally:
        app.dependency_overrides.clear()


def test_create_rejects_null_island_coordinates() -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    try:
        response = client.post(
            "/api/places",
            headers=_auth(),
            json={
                "name": "Invalid",
                "placeType": "other",
                "lat": 0.0,
                "lon": 0.0,
            },
        )
        assert response.status_code == 422
    finally:
        app.dependency_overrides.clear()
