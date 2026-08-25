"""API tests for HiAir 1.5 family caregiver stub."""

from fastapi.testclient import TestClient

import app.api.deps as deps
from app.main import app
from app.models.air import ProfileType, UserProfileContext
import app.services.air_repository as air_repository
import app.services.family_repository as family_repository

client = TestClient(app)


def _auth() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def _profile(user_id: str = "user-1", profile_id: str = "profile-child-1") -> UserProfileContext:
    return UserProfileContext(
        profile_id=profile_id,
        user_id=user_id,
        profile_type=ProfileType.ADULT_DEFAULT,
        age_group="adult",
        heat_sensitivity_level=2,
        respiratory_sensitivity_level=2,
        activity_level="moderate",
        timezone="UTC",
        home_lat=41.39,
        home_lon=2.17,
    )


def setup_function() -> None:
    family_repository.reset_store()
    family_repository.force_memory_store(True)


def teardown_function() -> None:
    family_repository.reset_store()
    family_repository.force_memory_store(False)
    app.dependency_overrides.clear()


def test_create_list_delete_family_member(monkeypatch) -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    monkeypatch.setattr(air_repository, "get_profile_context", lambda profile_id: _profile(profile_id=profile_id))
    created = client.post(
        "/api/family/members",
        headers=_auth(),
        json={"memberProfileId": "profile-child-1", "relation": "child", "label": "Mia"},
    )
    assert created.status_code == 200, created.text
    body = created.json()
    assert body["ownerUserId"] == "user-1"
    assert body["relation"] == "child"
    link_id = body["id"]

    listed = client.get("/api/family/members", headers=_auth())
    assert listed.status_code == 200
    assert len(listed.json()["members"]) == 1

    deleted = client.delete(f"/api/family/members/{link_id}", headers=_auth())
    assert deleted.status_code == 204
    assert client.get("/api/family/members", headers=_auth()).json()["members"] == []


def test_family_members_isolated_by_owner(monkeypatch) -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "owner-a"
    monkeypatch.setattr(air_repository, "get_profile_context", lambda profile_id: _profile(user_id="owner-a", profile_id=profile_id))
    created = client.post(
        "/api/family/members",
        headers=_auth(),
        json={"memberProfileId": "p1", "relation": "parent"},
    )
    link_id = created.json()["id"]

    app.dependency_overrides[deps.get_current_user_id] = lambda: "owner-b"
    assert client.get("/api/family/members", headers=_auth()).json()["members"] == []
    assert client.delete(f"/api/family/members/{link_id}", headers=_auth()).status_code == 404


def test_rejects_foreign_profile(monkeypatch) -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    monkeypatch.setattr(
        air_repository,
        "get_profile_context",
        lambda profile_id: _profile(user_id="other-user", profile_id=profile_id),
    )
    response = client.post(
        "/api/family/members",
        headers=_auth(),
        json={"memberProfileId": "p-foreign", "relation": "child"},
    )
    assert response.status_code == 403
