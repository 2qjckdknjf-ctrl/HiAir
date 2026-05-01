from fastapi.testclient import TestClient

from app.main import app


def test_privacy_export_includes_briefing_and_correlations(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    monkeypatch.setattr(
        "app.api.privacy.privacy_repository.export_user_data",
        lambda user_id: {
            "user": {"id": user_id, "email": "demo@hiair.app"},
            "briefing_schedule": {
                "user_id": user_id,
                "local_time": "07:30",
                "timezone": "Europe/Madrid",
                "enabled": True,
                "last_sent_at": None,
            },
            "personal_correlations": [
                {
                    "profile_id": "profile-1",
                    "factor_a": "pm25_avg",
                    "factor_b": "symptom_burden",
                    "coefficient": 0.52,
                    "p_value": 0.02,
                    "sample_size": 14,
                    "window_days": 30,
                }
            ],
        },
    )

    client = TestClient(app)
    response = client.get("/api/privacy/export", headers={"Authorization": "Bearer token"})
    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["user_id"] == "user-1"
    assert "briefing_schedule" in payload["data"]
    assert "personal_correlations" in payload["data"]
    assert payload["data"]["briefing_schedule"]["enabled"] is True
    assert payload["data"]["personal_correlations"][0]["factor_a"] == "pm25_avg"
