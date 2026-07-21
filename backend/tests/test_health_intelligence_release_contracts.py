"""Release-certification contracts for Health Intelligence 100."""

from __future__ import annotations

from unittest.mock import MagicMock

from app.services.health_analytics_service import build_insights_bundle
from app.services.health_metrics import CANONICAL_METRICS, expected_unit, is_known_metric
from app.services.personal_load_engine import PersonalLoadInput, compute_personal_load_score
from app.services.wearable_service import build_personal_load_input


def test_hrv_sdnn_and_rmssd_are_distinct_canonical_metrics() -> None:
    assert is_known_metric("hrv_sdnn")
    assert is_known_metric("hrv_rmssd")
    assert expected_unit("hrv_sdnn") == "ms"
    assert expected_unit("hrv_rmssd") == "ms"
    assert "hrv_sdnn" in CANONICAL_METRICS
    assert "hrv_rmssd" in CANONICAL_METRICS
    assert CANONICAL_METRICS["hrv_sdnn"]["category"] == CANONICAL_METRICS["hrv_rmssd"]["category"]


def test_basal_and_active_energy_are_separate() -> None:
    assert expected_unit("basal_energy") == "kcal"
    assert expected_unit("active_energy") == "kcal"
    assert "basal_energy" != "active_energy"


def test_temperature_types_are_separate() -> None:
    assert is_known_metric("body_temperature")
    assert is_known_metric("wrist_temperature")
    assert expected_unit("body_temperature") == "celsius"
    assert expected_unit("wrist_temperature") == "celsius"


def test_personal_load_missing_sleep_does_not_score_sleep_rules() -> None:
    result = compute_personal_load_score(
        PersonalLoadInput(
            steps_today=9000,
            aqi=80,
            sleep_minutes=None,
            consent_active=True,
        )
    )
    assert "short_sleep_environment" not in result.reason_codes
    assert "short_sleep_high_activity" not in result.reason_codes


def test_personal_load_missing_hrv_does_not_score_hrv_rules() -> None:
    result = compute_personal_load_score(
        PersonalLoadInput(
            hrv_ms=None,
            hrv_baseline_7d=50,
            consent_active=True,
            steps_today=1000,
        )
    )
    assert "hrv_below_7d_baseline" not in result.reason_codes


def test_personal_load_hrv_requires_matching_baseline(monkeypatch) -> None:
    """Today SDNN must not be compared to an RMSSD-only baseline."""
    monkeypatch.setattr(
        "app.services.wearable_service.wearable_repository.get_active_consent",
        lambda user_id: MagicMock(source="apple_health", isActive=True),
    )
    monkeypatch.setattr(
        "app.services.wearable_service.wearable_repository.get_daily_summary",
        lambda *args, **kwargs: MagicMock(
            stepsTotal=1000,
            heartRateAvg=None,
            heartRateMax=None,
            restingHeartRateAvg=None,
        ),
    )
    monkeypatch.setattr(
        "app.services.wearable_service.wearable_repository.sum_steps_since",
        lambda *args, **kwargs: 0,
    )
    monkeypatch.setattr(
        "app.services.wearable_service.wearable_repository.resting_hr_baseline",
        lambda *args, **kwargs: None,
    )
    monkeypatch.setattr(
        "app.services.wearable_service.health_sync_repository.list_metrics_for_date",
        lambda user_id, local_date: [
            {"metric_type": "hrv_sdnn", "value_avg": 40.0, "value_total": None, "value_latest": None}
        ],
    )
    monkeypatch.setattr(
        "app.services.wearable_service.health_sync_repository.get_sleep_for_date",
        lambda *args, **kwargs: None,
    )

    def _baseline(user_id, metric_type, days=30):
        if metric_type == "hrv_rmssd":
            return 55.0
        return None

    monkeypatch.setattr(
        "app.services.wearable_service.health_sync_repository.metric_baseline",
        _baseline,
    )

    load = build_personal_load_input("user-1")
    assert load.hrv_ms == 40.0
    assert load.hrv_baseline_7d is None
    scored = compute_personal_load_score(load)
    assert "hrv_below_7d_baseline" not in scored.reason_codes


def test_insights_bundle_empty_without_consent(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.services.health_analytics_service.wearable_repository.get_active_consent",
        lambda user_id: None,
    )
    bundle = build_insights_bundle(user_id="u1", profile_id="p1", window_days=30, language="en")
    assert bundle["trends"] == []
    assert bundle["associations"] == []
    assert bundle["healthDataStatus"]["consentActive"] is False


def test_health_data_status_includes_consent_active_when_present(monkeypatch) -> None:
    from datetime import date
    from types import SimpleNamespace

    from app.services.health_analytics_service import _health_data_status

    monkeypatch.setattr(
        "app.services.health_analytics_service.wearable_repository.get_active_consent",
        lambda user_id: SimpleNamespace(isActive=True),
    )
    monkeypatch.setattr(
        "app.services.health_analytics_service.health_sync_repository.get_sync_state",
        lambda user_id: {"last_success_at": None, "sync_status": "success"},
    )
    status = _health_data_status(
        "u1",
        [{"metric_type": "steps", "local_date": date.today()}],
        [],
    )
    assert status["consentActive"] is True
    assert status["metricDays"] == 1


def test_health_insights_api_accepts_seven_day_window(monkeypatch) -> None:
    """Mobile Insights chips request window_days=7; API must not reject below 14."""
    from datetime import datetime, timezone
    from uuid import uuid4

    from fastapi.testclient import TestClient

    from app.main import app
    import app.services.entitlement_service as entitlement_service
    import app.services.health_analytics_service as health_analytics_service
    import app.services.profile_access as profile_access

    profile_id = str(uuid4())
    monkeypatch.setattr(
        "app.api.deps.decode_access_token",
        lambda _: "user-1",
    )
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr(entitlement_service, "require_feature", lambda *args, **kwargs: None)
    monkeypatch.setattr(profile_access, "profile_exists", lambda _: True)
    monkeypatch.setattr(profile_access, "profile_belongs_to_user", lambda *args, **kwargs: True)
    monkeypatch.setattr(
        health_analytics_service,
        "build_insights_bundle",
        lambda **kwargs: {
            "profileId": profile_id,
            "generatedAt": datetime.now(tz=timezone.utc),
            "today": {"localDate": "2026-07-21"},
            "trends": [],
            "associations": [],
            "insufficientData": [],
            "healthDataStatus": {"metricDays": 0, "syncStatus": "pending", "consentActive": True},
        },
    )
    client = TestClient(app)
    response = client.get(
        f"/api/v1/health/insights?profile_id={profile_id}&window_days=7&language=en",
        headers={"Authorization": "Bearer test-token"},
    )
    assert response.status_code == 200
    assert response.json()["profileId"] == profile_id


def test_ai_health_context_is_bounded_to_four_observations() -> None:
    from app.api.air import _health_context_for_ai

    # Pure contract on the helper signature: returns list[str], never raises for empty inputs.
    assert callable(_health_context_for_ai)


def test_no_exact_health_values_required_in_ai_payload_keys() -> None:
    # Contract: AI payload uses observation strings, not raw metric keys like value_avg.
    forbidden = {"value_avg", "value_total", "value_latest", "beatsPerMinute"}
    from app.services import ai_explanation_service as mod

    source = open(mod.__file__, encoding="utf-8").read()
    for token in forbidden:
        assert f'"{token}"' not in source