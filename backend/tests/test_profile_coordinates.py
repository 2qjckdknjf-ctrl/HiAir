#!/usr/bin/env python3
"""Tests for profile home coordinate validation."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

import app.api.deps as deps
from app.core.geo_coordinates import coordinates_are_valid, validate_home_coordinates
from app.main import app
from app.models.risk import PersonaType
from app.models.user import ProfileResponse

client = TestClient(app)


def _auth_headers() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def _enable_auth(monkeypatch: pytest.MonkeyPatch, user_id: str = "user-1") -> None:
    monkeypatch.setattr(deps, "decode_access_token", lambda token: user_id)
    monkeypatch.setattr(deps.user_repository, "user_exists", lambda _user_id: True)


def test_validate_home_coordinates_accepts_real_point() -> None:
    validate_home_coordinates(41.39, 2.17)


def test_validate_home_coordinates_rejects_null_island() -> None:
    with pytest.raises(ValueError, match="null island"):
        validate_home_coordinates(0.0, 0.0)


def test_validate_home_coordinates_rejects_out_of_range() -> None:
    with pytest.raises(ValueError, match="home_lat"):
        validate_home_coordinates(91.0, 2.0)
    with pytest.raises(ValueError, match="home_lon"):
        validate_home_coordinates(41.0, 181.0)


def test_coordinates_are_valid_helper() -> None:
    assert coordinates_are_valid(48.85, 2.35)
    assert not coordinates_are_valid(0.0, 0.0)


def test_create_profile_rejects_null_island(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_auth(monkeypatch)
    response = client.post(
        "/api/profiles",
        headers=_auth_headers(),
        json={
            "persona_type": "adult",
            "sensitivity_level": "medium",
            "home_lat": 0.0,
            "home_lon": 0.0,
        },
    )
    assert response.status_code == 422


def test_patch_profile_rejects_null_island(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_auth(monkeypatch)
    profile = ProfileResponse(
        id="profile-1",
        user_id="user-1",
        persona_type=PersonaType.ADULT,
        sensitivity_level="medium",
        home_lat=41.39,
        home_lon=2.17,
        date_of_birth=None,
        age_years=None,
    )
    monkeypatch.setattr(deps.user_repository, "get_profile", lambda user_id, profile_id: profile)
    patch = client.patch(
        "/api/profiles/profile-1",
        headers=_auth_headers(),
        json={"home_lat": 0.0, "home_lon": 0.0},
    )
    assert patch.status_code in (400, 422)
    if patch.status_code == 400:
        assert "null island" in patch.json()["detail"].lower()
