from fastapi.testclient import TestClient

from app.main import app


def test_personal_patterns_empty_when_not_enough_data(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")

    class _Profile:
        user_id = "user-1"

    monkeypatch.setattr("app.api.insights.air_repository.get_profile_context", lambda _: _Profile())
    monkeypatch.setattr("app.api.insights.insights_repository.get_daily_correlation_samples", lambda profile_id, window_days: [])
    monkeypatch.setattr("app.api.insights.correlation_engine.compute_personal_patterns", lambda samples, language: [])
    monkeypatch.setattr(
        "app.api.insights.insights_repository.replace_personal_correlations",
        lambda profile_id, window_days, items: None,
    )

    client = TestClient(app)
    response = client.get(
        "/api/insights/personal-patterns",
        params={"profile_id": "profile-1", "window_days": 30, "language": "en"},
        headers={"Authorization": "Bearer token"},
    )
    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["profileId"] == "profile-1"
    assert payload["windowDays"] == 30
    assert payload["items"] == []
