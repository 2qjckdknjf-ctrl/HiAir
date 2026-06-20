from app.models.insights import PersonalPatternsResponse
from app.services import personal_patterns_service
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


class _FakeCursor:
    def __init__(self):
        self.executed_sql: list[str] = []

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def execute(self, sql, _params=None):
        self.executed_sql.append(sql)

    def fetchone(self):
        return {"symptom_aqi": 85.0, "clean_aqi": 55.0, "total": 4}


class _FakeConnection:
    def __init__(self, cursor: _FakeCursor):
        self._cursor = cursor

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def cursor(self):
        return self._cursor


def test_symptom_aqi_insight_joins_nearest_risk_snapshot(monkeypatch) -> None:
    fake_cursor = _FakeCursor()
    monkeypatch.setattr(
        personal_patterns_service,
        "get_connection",
        lambda: _FakeConnection(fake_cursor),
    )

    insight = personal_patterns_service._symptom_aqi_insight("profile-1")

    assert insight is not None
    assert "JOIN LATERAL" in fake_cursor.executed_sql[0]
    assert "r.created_at <= s.timestamp_utc" in fake_cursor.executed_sql[0]
