import app.services.personal_patterns_service as personal_patterns_service
from app.models.insights import PersonalPatternsResponse
from app.services.personal_patterns_service import MINIMUM_DAYS, build_personal_patterns


class _FakeCursor:
    def __init__(self, row: dict | None, queries: list[str]) -> None:
        self._row = row
        self._queries = queries

    def __enter__(self) -> "_FakeCursor":
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        return False

    def execute(self, query: str, _params) -> None:
        self._queries.append(query)

    def fetchone(self) -> dict | None:
        return self._row


class _FakeConnection:
    def __init__(self, row: dict | None, queries: list[str]) -> None:
        self._row = row
        self._queries = queries

    def __enter__(self) -> "_FakeConnection":
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        return False

    def cursor(self) -> _FakeCursor:
        return _FakeCursor(self._row, self._queries)


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


def test_symptom_aqi_insight_uses_time_aligned_snapshot_join(monkeypatch) -> None:
    queries: list[str] = []
    monkeypatch.setattr(
        personal_patterns_service,
        "get_connection",
        lambda: _FakeConnection({"total": 0}, queries),
    )

    assert personal_patterns_service._symptom_aqi_insight("profile-1") is None
    assert len(queries) == 1
    assert "LEFT JOIN LATERAL" in queries[0]
    assert "e.timestamp_utc BETWEEN s.timestamp_utc - INTERVAL '6 hours'" in queries[0]


def test_wearable_heat_insight_requires_hot_and_cool_day_comparison(monkeypatch) -> None:
    monkeypatch.setattr(
        personal_patterns_service,
        "get_connection",
        lambda: _FakeConnection(
            {"hot_days": 1, "cool_days": 0, "hot_hr": 83.0, "cool_hr": 75.0},
            [],
        ),
    )

    assert personal_patterns_service._wearable_heat_insight("user-1", "profile-1") is None


def test_wearable_heat_insight_returns_item_for_supported_pattern(monkeypatch) -> None:
    monkeypatch.setattr(
        personal_patterns_service,
        "get_connection",
        lambda: _FakeConnection(
            {"hot_days": 2, "cool_days": 2, "hot_hr": 84.0, "cool_hr": 77.0},
            [],
        ),
    )

    insight = personal_patterns_service._wearable_heat_insight("user-1", "profile-1")

    assert insight is not None
    assert insight.insight_type == "wearable_heat_correlation"
