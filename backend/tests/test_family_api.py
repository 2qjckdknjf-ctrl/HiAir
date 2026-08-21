"""API tests for HiAir 1.5 family caregiver stub."""

from fastapi.testclient import TestClient

import app.api.deps as deps
from app.main import app
import app.services.family_repository as family_repository

client = TestClient(app)


def _auth() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def setup_function() -> None:
    family_repository.reset_store()


def teardown_function() -> None:
    family_repository.reset_store()


def test_create_list_delete_family_member() -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    try:
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
    finally:
        app.dependency_overrides.clear()


def test_family_members_isolated_by_owner() -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "owner-a"
    try:
        created = client.post(
            "/api/family/members",
            headers=_auth(),
            json={"memberProfileId": "p1", "relation": "parent"},
        )
        link_id = created.json()["id"]
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[deps.get_current_user_id] = lambda: "owner-b"
    try:
        assert client.get("/api/family/members", headers=_auth()).json()["members"] == []
        assert client.delete(f"/api/family/members/{link_id}", headers=_auth()).status_code == 404
    finally:
        app.dependency_overrides.clear()
