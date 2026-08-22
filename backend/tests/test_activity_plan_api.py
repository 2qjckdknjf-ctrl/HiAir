"""API tests for HiAir 1.2 activity planner routes."""

import app.api.air as air_api
import app.api.planner as planner_api
from app.api import deps
from app.main import app
from app.models.activity_plan import ActivityType
from app.models.air import EnvironmentalInput, ProfileType, UserProfileContext
from app.models.places import PlaceType, SavedPlace
from fastapi.testclient import TestClient

client = TestClient(app)


def _auth() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def _profile() -> UserProfileContext:
    return UserProfileContext(
        profile_id="profile-1",
        user_id="user-1",
        profile_type=ProfileType.ADULT_DEFAULT,
        home_lat=41.39,
        home_lon=2.17,
        timezone="Europe/Madrid",
    )


def _env(
    ts: str = "2026-08-21T07:00:00+02:00",
    *,
    feels_like: float = 24.0,
    aqi: int | None = 40,
    pm25: float | None = 10.0,
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
        ozone=40.0,
        uv=3.0,
        wind_speed=2.0,
        source="openmeteo",
        timestamp=ts,
        timezone="Europe/Madrid",
    )


def test_activities_catalog_ok() -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    try:
        response = client.get("/api/planner/activities", headers=_auth())
        assert response.status_code == 200
        body = response.json()
        values = {item["activity"] for item in body["activities"]}
        assert "running" in values
        assert "ventilation" in values
    finally:
        app.dependency_overrides.clear()


def test_activity_plan_returns_windows(monkeypatch) -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    monkeypatch.setattr(
        planner_api.entitlement_service,
        "require_feature",
        lambda *args, **kwargs: None,
    )
    monkeypatch.setattr(air_api, "_resolve_profile_for_user", lambda profile_id, user_id: _profile())
    monkeypatch.setattr(
        planner_api.air_environment_service,
        "load_environment",
        lambda profile: _env(),
    )
    cool = _env("2026-08-21T07:00:00+02:00", feels_like=23.0)
    hot = _env("2026-08-21T14:00:00+02:00", feels_like=37.0, aqi=140, pm25=45.0)

    class _FakeForecast:
        generated_at = "2026-08-21T06:55:00+02:00"
        freshness = type("F", (), {"value": "live"})()
        quality = type("Q", (), {"value": "complete"})()
        sources = ["openmeteo"]
        missing_metrics: list[str] = []

    monkeypatch.setattr(air_api, "_load_forecast_or_none", lambda lat, lon: _FakeForecast())
    monkeypatch.setattr(planner_api, "forecast_to_hourly_inputs", lambda forecast: [cool, hot])
    monkeypatch.setattr(
        planner_api.wearable_service,
        "build_personal_load_input",
        lambda user_id, environment: None,
    )

    try:
        response = client.post(
            "/api/planner/activity-plan",
            headers=_auth(),
            json={
                "profileId": "profile-1",
                "activity": ActivityType.RUNNING.value,
                "durationMinutes": 45,
            },
        )
        assert response.status_code == 200, response.text
        body = response.json()
        assert body["activity"] == "running"
        assert body["forecastAvailable"] is True
        assert body["recommendedStart"] == "2026-08-21T07:00:00+02:00"
        tiers = {window["tier"] for window in body["windows"]}
        assert "best" in tiers
        assert "avoid" in tiers
    finally:
        app.dependency_overrides.clear()


def test_activity_plan_empty_forecast_is_honest(monkeypatch) -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    monkeypatch.setattr(
        planner_api.entitlement_service,
        "require_feature",
        lambda *args, **kwargs: None,
    )
    monkeypatch.setattr(air_api, "_resolve_profile_for_user", lambda profile_id, user_id: _profile())
    monkeypatch.setattr(
        planner_api.air_environment_service,
        "load_environment",
        lambda profile: _env(),
    )
    monkeypatch.setattr(air_api, "_load_forecast_or_none", lambda lat, lon: None)
    monkeypatch.setattr(
        planner_api.wearable_service,
        "build_personal_load_input",
        lambda user_id, environment: None,
    )

    try:
        response = client.post(
            "/api/planner/activity-plan",
            headers=_auth(),
            json={"profileId": "profile-1", "activity": "walking"},
        )
        assert response.status_code == 200, response.text
        body = response.json()
        assert body["forecastAvailable"] is False
        assert body["recommendedStart"] is None
        assert body["windows"] == []
        assert body["dataQuality"] == "unavailable"
    finally:
        app.dependency_overrides.clear()


def test_activity_plan_uses_saved_place_environment(monkeypatch) -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    monkeypatch.setattr(
        planner_api.entitlement_service,
        "require_feature",
        lambda *args, **kwargs: None,
    )
    monkeypatch.setattr(air_api, "_resolve_profile_for_user", lambda profile_id, user_id: _profile())
    place = SavedPlace(
        id="place-1",
        userId="user-1",
        name="Beach",
        placeType=PlaceType.VACATION,
        lat=36.12,
        lon=-5.35,
        timezone="Europe/Madrid",
    )
    monkeypatch.setattr(planner_api.places_repository, "get_place", lambda **kwargs: place)
    load_calls: list[tuple[float, float, str | None]] = []

    def _load_environment(profile: UserProfileContext) -> EnvironmentalInput:
        load_calls.append((profile.home_lat, profile.home_lon, profile.location_name))
        return EnvironmentalInput(
            lat=profile.home_lat,
            lon=profile.home_lon,
            temperature=25.0,
            feels_like=26.0,
            humidity=55.0,
            aqi=42,
            pm25=11.0,
            pm10=16.0,
            ozone=41.0,
            uv=4.0,
            wind_speed=3.0,
            source="openmeteo",
            timestamp="2026-08-21T07:00:00+02:00",
            timezone=profile.timezone,
        )

    monkeypatch.setattr(planner_api.air_environment_service, "load_environment", _load_environment)
    monkeypatch.setattr(air_api, "_load_forecast_or_none", lambda lat, lon: None)
    seen_env: list[tuple[float, float]] = []
    monkeypatch.setattr(
        planner_api.wearable_service,
        "build_personal_load_input",
        lambda user_id, environment: seen_env.append((environment.lat, environment.lon)) or None,
    )

    try:
        response = client.post(
            "/api/planner/activity-plan",
            headers=_auth(),
            json={
                "profileId": "profile-1",
                "activity": ActivityType.WALKING.value,
                "placeId": place.id,
            },
        )
        assert response.status_code == 200, response.text
        assert load_calls == [(place.lat, place.lon, place.name)]
        assert seen_env == [(place.lat, place.lon)]
    finally:
        app.dependency_overrides.clear()
