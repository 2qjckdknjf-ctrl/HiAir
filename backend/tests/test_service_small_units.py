from app.models.risk import RiskEstimateResponse
import app.services.notification_service as notification_service
import app.services.profile_access as profile_access
import app.services.recommendation_service as recommendation_service
import app.services.request_rate_limiter as request_rate_limiter
import app.services.risk_validation_service as risk_validation_service


def test_recommendation_service_builds_summary_and_symptom_actions() -> None:
    summary, actions = recommendation_service.build_daily_recommendation(
        risk_level="medium",
        symptom_stats={
            "wheeze_count": 1,
            "cough_count": 2,
            "fatigue_count": 2,
            "headache_count": 2,
        },
    )
    assert "moderate risk" in summary.lower()
    assert len(actions) >= 4


def test_notification_service_handles_levels() -> None:
    high = RiskEstimateResponse(score=70, level="high", recommendations=[], components={})
    moderate = RiskEstimateResponse(score=45, level="medium", recommendations=[], components={})
    assert notification_service.should_notify(high) is True
    assert notification_service.should_notify(moderate) is False
    assert "High air/heat risk" in notification_service.build_notification_text(high)
    assert "Moderate risk conditions" in notification_service.build_notification_text(moderate)


def test_request_rate_limiter_respects_window() -> None:
    request_rate_limiter.reset_for_tests()
    key = "test-key"
    assert request_rate_limiter.check_limit(key=key, limit=2, window_seconds=60) is True
    assert request_rate_limiter.check_limit(key=key, limit=2, window_seconds=60) is True
    assert request_rate_limiter.check_limit(key=key, limit=2, window_seconds=60) is False
    request_rate_limiter.reset_for_tests()
    assert request_rate_limiter.check_limit(key=key, limit=2, window_seconds=60) is True


class _FakeCursor:
    def __init__(self, row):
        self._row = row

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def execute(self, query, params):
        return None

    def fetchone(self):
        return self._row


class _FakeConnection:
    def __init__(self, row):
        self._row = row

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def cursor(self):
        return _FakeCursor(self._row)


def test_profile_access_checks_existence_and_ownership(monkeypatch) -> None:
    monkeypatch.setattr(profile_access, "get_connection", lambda: _FakeConnection((1,)))
    assert profile_access.profile_exists("profile-1") is True
    assert profile_access.profile_belongs_to_user("profile-1", "user-1") is True

    monkeypatch.setattr(profile_access, "get_connection", lambda: _FakeConnection(None))
    assert profile_access.profile_exists("profile-1") is False
    assert profile_access.profile_belongs_to_user("profile-1", "user-1") is False


def test_risk_validation_service_returns_summary(monkeypatch) -> None:
    monkeypatch.setattr(
        risk_validation_service,
        "estimate_risk",
        lambda persona, symptoms, environment: (80, "very_high", [], {}),
    )
    report = risk_validation_service.run_historical_validation()
    assert report.total_cases == 4
    assert report.passed is True
    assert report.passed_cases == 4
