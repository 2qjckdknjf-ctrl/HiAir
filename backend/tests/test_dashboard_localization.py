from app.api.dashboard import dashboard_overview


def test_dashboard_overview_uses_language_for_daily_copy(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.api.dashboard.settings_repository.get_user_settings",
        lambda user_id: type("Settings", (), {"preferred_language": "en"})(),
    )

    response = dashboard_overview(user_id="user-1")

    assert response.daily_summary == "Conditions are moderate risk."
    assert response.notification_text == "Moderate risk conditions. Plan safer time windows."


def test_dashboard_overview_honors_language_query(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.api.dashboard.settings_repository.get_user_settings",
        lambda user_id: type("Settings", (), {"preferred_language": "en"})(),
    )

    response = dashboard_overview(language="ru", user_id="user-1")

    assert response.daily_summary == "Условия умеренного риска."
    assert response.notification_text == "Условия умеренного риска. Планируйте более безопасные временные окна."
