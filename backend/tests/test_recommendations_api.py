from app.api.recommendations import daily_recommendation


def test_daily_recommendation_is_available_without_subscription(monkeypatch) -> None:
    monkeypatch.setattr("app.api.recommendations.profile_access.profile_exists", lambda profile_id: True)
    monkeypatch.setattr("app.api.recommendations.profile_access.profile_belongs_to_user", lambda profile_id, user_id: True)
    monkeypatch.setattr("app.api.recommendations.risk_repository.get_risk_history", lambda profile_id, limit: [])
    monkeypatch.setattr(
        "app.api.recommendations.risk_repository.get_recent_symptom_stats",
        lambda profile_id, hours: {
            "cough_count": 0,
            "wheeze_count": 0,
            "headache_count": 0,
            "fatigue_count": 0,
            "total_logs": 0,
        },
    )
    monkeypatch.setattr(
        "app.api.recommendations.settings_repository.get_user_settings",
        lambda user_id: type("Settings", (), {"preferred_language": "ru"})(),
    )

    response = daily_recommendation(profile_id="profile-1", user_id="user-1")

    assert response.profile_id == "profile-1"
    assert response.risk_level == "low"
    assert response.summary
    assert response.actions


def test_daily_recommendation_honors_language_query(monkeypatch) -> None:
    monkeypatch.setattr("app.api.recommendations.profile_access.profile_exists", lambda profile_id: True)
    monkeypatch.setattr("app.api.recommendations.profile_access.profile_belongs_to_user", lambda profile_id, user_id: True)
    monkeypatch.setattr(
        "app.api.recommendations.risk_repository.get_risk_history",
        lambda profile_id, limit: [{"risk_level": "high"}],
    )
    monkeypatch.setattr(
        "app.api.recommendations.risk_repository.get_recent_symptom_stats",
        lambda profile_id, hours: {
            "cough_count": 2,
            "wheeze_count": 0,
            "headache_count": 0,
            "fatigue_count": 0,
            "total_logs": 2,
        },
    )

    response = daily_recommendation(profile_id="profile-1", language="ru", user_id="user-1")

    assert response.summary == "Условия высокого риска."
    assert "Повторяющийся кашель" in response.actions[-1]
