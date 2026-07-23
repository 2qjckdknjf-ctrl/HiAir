from datetime import UTC, datetime
from types import SimpleNamespace

from app.services.briefing_service import _is_due, compose_briefing


def test_is_due_true_when_local_time_matches_and_not_sent_recently() -> None:
    now_utc = datetime(2026, 5, 1, 5, 30, tzinfo=UTC)  # 07:30 in Europe/Madrid (summer)
    assert _is_due(
        now_utc=now_utc,
        local_time="07:30",
        timezone_name="Europe/Madrid",
        last_sent_at=None,
    )


def test_is_due_false_when_already_sent_recently() -> None:
    now_utc = datetime(2026, 5, 1, 5, 30, tzinfo=UTC)
    assert not _is_due(
        now_utc=now_utc,
        local_time="07:30",
        timezone_name="Europe/Madrid",
        last_sent_at="2026-05-01T00:30:00+00:00",
    )


def test_compose_briefing_uses_personal_load_for_plan_and_health_associations(
    monkeypatch,
) -> None:
    captured: dict[str, object] = {}
    personal_load = object()

    monkeypatch.setattr(
        "app.services.briefing_service.briefing_repository.get_user_profile_ids",
        lambda _: ["profile-1"],
    )
    monkeypatch.setattr(
        "app.services.briefing_service.air_repository.get_profile_context",
        lambda _: SimpleNamespace(profile_id="profile-1", user_id="user-1"),
    )
    monkeypatch.setattr(
        "app.services.briefing_service.settings_repository.get_user_settings",
        lambda _: SimpleNamespace(preferred_language="en"),
    )
    monkeypatch.setattr(
        "app.services.briefing_service.air_environment_service.load_environment",
        lambda _: SimpleNamespace(),
    )
    monkeypatch.setattr(
        "app.services.briefing_service.wearable_service.build_personal_load_input",
        lambda *args, **kwargs: personal_load,
    )
    monkeypatch.setattr(
        "app.services.briefing_service.air_risk_engine.evaluate_risk",
        lambda *args, **kwargs: SimpleNamespace(
            overallRisk=SimpleNamespace(value="high")
        ),
    )

    def _build_day_plan(profile, environment, passed_personal_load=None):
        captured["personal_load"] = passed_personal_load
        return SimpleNamespace(
            safeWindows=[SimpleNamespace(start="07:00", end="09:00")]
        )

    monkeypatch.setattr(
        "app.services.briefing_service.air_risk_engine.build_day_plan", _build_day_plan
    )
    monkeypatch.setattr(
        "app.services.briefing_service.air_recommendation_engine.generate_recommendation",
        lambda *args, **kwargs: SimpleNamespace(
            headline="Hydrate", actions=["Hydrate"]
        ),
    )
    monkeypatch.setattr(
        "app.services.briefing_service.wearable_repository.get_active_consent",
        lambda _: SimpleNamespace(isActive=True),
    )
    monkeypatch.setattr(
        "app.services.briefing_service.entitlement_service.get_current_entitlement",
        lambda _: SimpleNamespace(is_premium=True, advanced_insights_enabled=True),
    )
    monkeypatch.setattr(
        "app.services.briefing_service.health_analytics_service.build_insights_bundle",
        lambda **kwargs: {
            "associations": [
                {"title": "Recovery", "observation": "Low sleep can raise effort."}
            ],
            "trends": [
                {"title": "Trend", "observation": "Activity has been climbing."}
            ],
        },
    )

    def _generate_explanation(*args, **kwargs):
        captured["health_context"] = kwargs["health_context"]
        return "Take it easier this morning.", "llm"

    monkeypatch.setattr(
        "app.services.briefing_service.ai_explanation_service.generate_explanation",
        _generate_explanation,
    )

    message, profile_id, risk_level = compose_briefing("user-1")

    assert captured["personal_load"] is personal_load
    assert captured["health_context"] == [
        "Recovery: Low sleep can raise effort.",
        "Trend: Activity has been climbing.",
    ]
    assert "Best outdoor window: 07:00-09:00." in message
    assert profile_id == "profile-1"
    assert risk_level == "high"
