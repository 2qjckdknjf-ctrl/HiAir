from fastapi.testclient import TestClient

from app.main import app


def test_briefing_schedule_roundtrip(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    monkeypatch.setattr("app.api.briefings._resolve_timezone", lambda _: "Europe/Madrid")

    monkeypatch.setattr(
        "app.api.briefings.briefing_repository.get_schedule",
        lambda user_id, timezone: {
            "user_id": user_id,
            "local_time": "07:30",
            "timezone": timezone,
            "enabled": False,
            "last_sent_at": None,
        },
    )
    monkeypatch.setattr(
        "app.api.briefings.briefing_repository.upsert_schedule",
        lambda user_id, payload, timezone: {
            "user_id": user_id,
            "local_time": payload.local_time,
            "timezone": timezone,
            "enabled": payload.enabled,
            "last_sent_at": None,
        },
    )

    client = TestClient(app)
    get_resp = client.get("/api/briefings/schedule", headers={"Authorization": "Bearer token"})
    assert get_resp.status_code == 200, get_resp.text
    assert get_resp.json()["timezone"] == "Europe/Madrid"

    put_resp = client.put(
        "/api/briefings/schedule",
        headers={"Authorization": "Bearer token"},
        json={"local_time": "08:15", "enabled": True},
    )
    assert put_resp.status_code == 200, put_resp.text
    assert put_resp.json()["local_time"] == "08:15"
    assert put_resp.json()["enabled"] is True
