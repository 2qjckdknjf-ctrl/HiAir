from app.models.insights import PersonalPatternsResponse
from app.services.personal_patterns_service import MINIMUM_DAYS, build_personal_patterns


def test_personal_patterns_not_ready_with_few_days(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.services.personal_patterns_service._days_observed",
        lambda _profile_id: 2,
    )
    result = build_personal_patterns(profile_id="profile-1", user_id="user-1")
    assert isinstance(result, PersonalPatternsResponse)
    assert result.ready is False
    assert result.days_observed == 2
    assert result.minimum_days_required == MINIMUM_DAYS
    assert "наблюдений" in result.status_ru


def test_personal_patterns_ready_with_insights(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.services.personal_patterns_service._days_observed",
        lambda _profile_id: 10,
    )
    monkeypatch.setattr(
        "app.services.personal_patterns_service._symptom_aqi_insight",
        lambda _profile_id: None,
    )
    monkeypatch.setattr(
        "app.services.personal_patterns_service._time_of_day_insight",
        lambda _profile_id: None,
    )
    monkeypatch.setattr(
        "app.services.personal_patterns_service._wearable_heat_insight",
        lambda _user_id, _profile_id: None,
    )
    result = build_personal_patterns(profile_id="profile-1", user_id="user-1")
    assert result.days_observed == 10
    assert result.ready is False
    assert result.insights == []
