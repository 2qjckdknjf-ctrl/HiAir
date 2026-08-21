"""Tests for protected-day event persistence wired into adaptation."""

from datetime import UTC, datetime

from fastapi.testclient import TestClient

import app.api.deps as deps
from app.main import app
import app.services.air_repository as air_repository
import app.services.entitlement_service as entitlement_service
import app.services.protected_day_events_repository as protected_day_events_repository
from app.models.air import ProfileType, UserProfileContext
from app.models.wearable import WearableConsentResponse, WearablePlatform, WearableSource

client = TestClient(app)


def _auth() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def setup_function() -> None:
    protected_day_events_repository.force_memory_store(True)
    protected_day_events_repository.reset_store()


def teardown_function() -> None:
    protected_day_events_repository.reset_store()
    protected_day_events_repository.force_memory_store(False)
    app.dependency_overrides.clear()


def _profile() -> UserProfileContext:
    return UserProfileContext(
        profile_id="profile-1",
        user_id="user-1",
        profile_type=ProfileType.ADULT_DEFAULT,
        age_group="adult",
        heat_sensitivity_level=2,
        respiratory_sensitivity_level=2,
        activity_level="moderate",
        timezone="UTC",
        home_lat=41.39,
        home_lon=2.17,
    )


def _inactive_consent() -> WearableConsentResponse:
    return WearableConsentResponse(
        id="consent-1",
        userId="user-1",
        platform=WearablePlatform.IOS,
        source=WearableSource.APPLE_HEALTH,
        stepsEnabled=False,
        heartRateEnabled=False,
        restingHeartRateEnabled=False,
        hrvEnabled=False,
        sleepEnabled=False,
        consentVersion="wearables-v1",
        acceptedAt=datetime.now(tz=UTC),
        revokedAt=datetime.now(tz=UTC),
        isActive=False,
    )


def test_record_protected_day_event_and_surface_in_adaptation(monkeypatch) -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    monkeypatch.setattr(
        entitlement_service,
        "require_feature",
        lambda *args, **kwargs: None,
    )
    monkeypatch.setattr(air_repository, "get_profile_context", lambda _: _profile())
    monkeypatch.setattr(
        "app.services.wearable_repository.get_active_consent",
        lambda _: _inactive_consent(),
    )

    created = client.post(
        "/api/insights/protected-day-events",
        headers=_auth(),
        json={
            "profileId": "profile-1",
            "eventType": "workout_moved",
            "eventDate": "2026-08-20",
        },
    )
    assert created.status_code == 200, created.text
    assert created.json()["eventType"] == "workout_moved"

    snapshot = client.get(
        "/api/insights/adaptation?profileId=profile-1",
        headers=_auth(),
    )
    assert snapshot.status_code == 200, snapshot.text
    body = snapshot.json()
    assert body["protectedDays"]["available"] is True
    assert body["protectedDays"]["workoutsMoved"] == 1
    assert "protected_days_from_structured_events" in body["reasonCodes"]


def test_rejects_unknown_protected_day_event_type(monkeypatch) -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    monkeypatch.setattr(
        entitlement_service,
        "require_feature",
        lambda *args, **kwargs: None,
    )
    monkeypatch.setattr(air_repository, "get_profile_context", lambda _: _profile())

    response = client.post(
        "/api/insights/protected-day-events",
        headers=_auth(),
        json={"profileId": "profile-1", "eventType": "diagnosed_asthma"},
    )
    assert response.status_code == 422
