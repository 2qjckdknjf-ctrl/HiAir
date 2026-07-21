"""Regression: insights today exposes synced wellness metrics for UI."""

from unittest.mock import MagicMock

from app.services import health_analytics_service


def test_today_payload_includes_wellness_metric_keys(monkeypatch):
    """UI HealthToday / Insights today depend on these keys existing."""
    # Smoke the structure builder with empty stores via monkeypatch of repository.
    monkeypatch.setattr(
        health_analytics_service.wearable_repository,
        "get_active_consent",
        lambda *a, **k: MagicMock(isActive=True),
    )
    monkeypatch.setattr(
        health_analytics_service.health_sync_repository,
        "list_metrics_window",
        lambda *a, **k: [],
    )
    monkeypatch.setattr(
        health_analytics_service.health_sync_repository,
        "get_sleep_window",
        lambda *a, **k: [],
    )
    monkeypatch.setattr(
        health_analytics_service,
        "_load_environment_by_day",
        lambda *a, **k: {},
    )
    monkeypatch.setattr(
        health_analytics_service,
        "_load_symptoms_by_day",
        lambda *a, **k: {},
    )
    monkeypatch.setattr(
        health_analytics_service,
        "_load_risk_by_day",
        lambda *a, **k: {},
    )
    monkeypatch.setattr(
        health_analytics_service,
        "_health_data_status",
        lambda *a, **k: {"syncStatus": "pending", "metricDays": 0, "sleepDays": 0},
    )

    bundle = health_analytics_service.build_insights_bundle(
        user_id="00000000-0000-0000-0000-000000000001",
        profile_id="00000000-0000-0000-0000-000000000002",
        window_days=7,
        language="en",
    )
    today = bundle["today"]
    required = {
        "steps",
        "distanceMeters",
        "activeEnergyKcal",
        "exerciseMinutes",
        "standMinutes",
        "flightsClimbed",
        "workoutCount",
        "workoutDurationMinutes",
        "heartRate",
        "restingHeartRate",
        "walkingHeartRate",
        "hrv",
        "respiratoryRate",
        "oxygenSaturation",
        "bodyTemperature",
        "wristTemperature",
        "vo2Max",
        "sleepMinutes",
        "sleepDeepMinutes",
        "sleepRemMinutes",
        "sleepCoreMinutes",
        "sleepAwakeMinutes",
        "sleepInBedMinutes",
    }
    missing = required - set(today)
    assert not missing, f"missing today keys: {sorted(missing)}"
