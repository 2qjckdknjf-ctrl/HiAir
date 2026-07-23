"""AI report endpoint contracts for product polish sprint."""

from __future__ import annotations

from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app


def _auth(monkeypatch, user_id: str = "user-1") -> None:
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: user_id)
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)


def test_ai_report_requires_auth() -> None:
    client = TestClient(app)
    response = client.get(f"/api/ai/reports/morning?profile_id={uuid4()}")
    assert response.status_code == 401


def test_ai_report_rejects_unknown_kind(monkeypatch) -> None:
    _auth(monkeypatch)
    client = TestClient(app)
    response = client.get(
        f"/api/ai/reports/noon?profile_id={uuid4()}",
        headers={"Authorization": "Bearer t"},
    )
    assert response.status_code == 400


def test_morning_report_shape(monkeypatch) -> None:
    profile_id = str(uuid4())
    _auth(monkeypatch)
    monkeypatch.setattr("app.api.ai_reports.profile_access.profile_exists", lambda _: True)
    monkeypatch.setattr("app.api.ai_reports.profile_access.profile_belongs_to_user", lambda *a, **k: True)
    monkeypatch.setattr(
        "app.api.ai_reports.ai_report_service.build_ai_report",
        lambda **kwargs: {
            "kind": "morning",
            "profileId": profile_id,
            "generatedAt": datetime.now(tz=timezone.utc),
            "localDate": "2026-07-21",
            "windowDays": 1,
            "riskLevel": "moderate",
            "headline": "Stay hydrated",
            "narrative": "Air is moderate today. Keep outdoor effort shorter.",
            "actions": ["Hydrate", "Ventilate mid-day"],
            "healthContextPresent": False,
            "healthObservationCount": 0,
            "personalLoad": None,
            "explanationSource": "template_fallback",
            "environmentSource": "sample",
        },
    )
    client = TestClient(app)
    response = client.get(
        f"/api/ai/reports/morning?profile_id={profile_id}",
        headers={"Authorization": "Bearer t"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["kind"] == "morning"
    assert body["narrative"]
    assert "value_avg" not in body["narrative"].lower()


def test_evening_report_premium_gated(monkeypatch) -> None:
    from fastapi import HTTPException

    profile_id = str(uuid4())
    _auth(monkeypatch)
    monkeypatch.setattr("app.api.ai_reports.profile_access.profile_exists", lambda _: True)
    monkeypatch.setattr("app.api.ai_reports.profile_access.profile_belongs_to_user", lambda *a, **k: True)

    def _require(*args, **kwargs):
        raise HTTPException(status_code=402, detail="Premium required")

    monkeypatch.setattr(
        "app.services.ai_report_service.entitlement_service.require_feature",
        _require,
    )
    monkeypatch.setattr(
        "app.services.ai_report_service.air_repository.get_profile_context",
        lambda pid: SimpleNamespace(profile_id=pid, user_id="user-1"),
    )
    client = TestClient(app)
    response = client.get(
        f"/api/ai/reports/evening?profile_id={profile_id}",
        headers={"Authorization": "Bearer t"},
    )
    assert response.status_code == 402
