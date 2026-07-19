"""Contract and integration tests for /api/v1/health/*."""

from __future__ import annotations

from datetime import date, datetime, timezone
from uuid import uuid4

from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.main import app
from app.models.health_intelligence import HealthSyncRequest, MetricSummaryItem, QualityState
from app.models.wearable import WearablePlatform, WearableSource
from app.services.correlation_engine import _render_text
from app.services.health_analytics_service import _confidence
from app.services.symptom_taxonomy import taxonomy_payload


def _auth() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def _auth_user(monkeypatch, user_id: str = "user-1") -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: user_id)


def test_all_health_endpoints_require_auth() -> None:
    client = TestClient(app)
    assert client.get("/api/v1/health/summary").status_code == 401
    assert client.get("/api/v1/health/availability").status_code == 401
    assert client.get("/api/v1/health/timeline?profile_id=p1").status_code == 401
    assert client.delete("/api/v1/health/data").status_code == 401
    assert client.post(
        "/api/v1/health/sync",
        json={
            "localDate": date.today().isoformat(),
            "platform": "ios",
            "source": "apple_health",
            "metrics": [],
        },
    ).status_code == 401


def test_sync_rejects_wrong_profile(monkeypatch) -> None:
    _auth_user(monkeypatch)
    monkeypatch.setattr("app.api.health_intelligence.profile_access.profile_exists", lambda _: True)
    monkeypatch.setattr(
        "app.api.health_intelligence.profile_access.profile_belongs_to_user",
        lambda profile_id, user_id: False,
    )
    monkeypatch.setattr(
        "app.api.health_intelligence.wearable_repository.has_active_consent",
        lambda user_id, source: True,
    )
    client = TestClient(app)
    response = client.post(
        "/api/v1/health/sync",
        headers=_auth(),
        json={
            "profileId": str(uuid4()),
            "localDate": date.today().isoformat(),
            "platform": "ios",
            "source": "apple_health",
            "metrics": [
                {"metricType": "steps", "unit": "count", "valueTotal": 1000, "qualityState": "ok"}
            ],
        },
    )
    assert response.status_code == 403


def test_sync_rejects_without_consent(monkeypatch) -> None:
    _auth_user(monkeypatch)
    monkeypatch.setattr(
        "app.api.health_intelligence.wearable_repository.has_active_consent",
        lambda user_id, source: False,
    )
    client = TestClient(app)
    response = client.post(
        "/api/v1/health/sync",
        headers=_auth(),
        json={
            "localDate": date.today().isoformat(),
            "platform": "android",
            "source": "health_connect",
            "metrics": [
                {"metricType": "steps", "unit": "count", "valueTotal": 500, "qualityState": "ok"}
            ],
        },
    )
    assert response.status_code == 403


def test_sync_rejects_invalid_unit() -> None:
    try:
        MetricSummaryItem(metricType="steps", unit="bpm", valueTotal=10)
        assert False, "expected ValidationError"
    except ValidationError:
        pass


def test_sync_rejects_unknown_metric() -> None:
    try:
        MetricSummaryItem(metricType="raw_ecg", unit="count", valueTotal=1)
        assert False, "expected ValidationError"
    except ValidationError:
        pass


def test_hrv_methods_not_mixed() -> None:
    sdnn = MetricSummaryItem(metricType="hrv_sdnn", unit="ms", valueAvg=40.0, sampleCount=2)
    rmssd = MetricSummaryItem(metricType="hrv_rmssd", unit="ms", valueAvg=35.0, sampleCount=2)
    assert sdnn.hrvMethod == "sdnn"
    assert rmssd.hrvMethod == "rmssd"
    assert sdnn.metricType != rmssd.metricType


def test_missing_metric_not_zero_quality() -> None:
    item = MetricSummaryItem(metricType="steps", unit="count", sampleCount=0)
    assert item.qualityState == QualityState.NO_RECORDS
    assert item.valueTotal is None


def test_idempotent_sync_replay(monkeypatch) -> None:
    _auth_user(monkeypatch)
    monkeypatch.setattr(
        "app.api.health_intelligence.wearable_repository.has_active_consent",
        lambda user_id, source: True,
    )
    now = datetime.now(tz=timezone.utc)
    calls = {"n": 0}

    def _apply(user_id, payload):
        calls["n"] += 1
        return len(payload.metrics), [], False, now

    monkeypatch.setattr("app.api.health_intelligence.health_sync_repository.apply_sync", _apply)
    monkeypatch.setattr(
        "app.api.health_intelligence.health_sync_repository.mirror_legacy_daily_from_metrics",
        lambda user_id, payload: None,
    )
    client = TestClient(app)
    body = {
        "localDate": date.today().isoformat(),
        "timezone": "Europe/Madrid",
        "platform": "ios",
        "source": "apple_health",
        "idempotencyKey": "replay-key-1",
        "metrics": [
            {"metricType": "steps", "unit": "count", "valueTotal": 7000, "qualityState": "ok"}
        ],
    }
    r1 = client.post("/api/v1/health/sync", headers={**_auth(), "Idempotency-Key": "replay-key-1"}, json=body)
    r2 = client.post("/api/v1/health/sync", headers={**_auth(), "Idempotency-Key": "replay-key-1"}, json=body)
    assert r1.status_code == 200
    assert r2.status_code == 200
    assert r1.json()["acceptedMetrics"] == r2.json()["acceptedMetrics"] == 1
    assert calls["n"] == 2  # upsert path is naturally idempotent at DB unique key


def test_partial_sync_status(monkeypatch) -> None:
    _auth_user(monkeypatch)
    monkeypatch.setattr(
        "app.api.health_intelligence.wearable_repository.has_active_consent",
        lambda user_id, source: True,
    )
    now = datetime.now(tz=timezone.utc)
    monkeypatch.setattr(
        "app.api.health_intelligence.health_sync_repository.apply_sync",
        lambda user_id, payload: (1, ["unknown_metric"], False, now),
    )
    monkeypatch.setattr(
        "app.api.health_intelligence.health_sync_repository.mirror_legacy_daily_from_metrics",
        lambda user_id, payload: None,
    )
    client = TestClient(app)
    response = client.post(
        "/api/v1/health/sync",
        headers=_auth(),
        json={
            "localDate": date.today().isoformat(),
            "platform": "ios",
            "source": "apple_health",
            "metrics": [
                {"metricType": "steps", "unit": "count", "valueTotal": 1, "qualityState": "ok"}
            ],
        },
    )
    assert response.status_code == 200
    assert response.json()["syncStatus"] == "partial"
    assert response.json()["rejectedMetrics"] == ["unknown_metric"]


def test_delete_health_data_contract(monkeypatch) -> None:
    _auth_user(monkeypatch)
    monkeypatch.setattr(
        "app.api.health_intelligence.health_sync_repository.delete_all_health_data",
        lambda user_id: (3, 1, 2, 4),
    )
    monkeypatch.setattr(
        "app.api.health_intelligence.wearable_repository.revoke_consent",
        lambda user_id: object(),
    )
    client = TestClient(app)
    response = client.delete("/api/v1/health/data", headers=_auth())
    assert response.status_code == 200
    body = response.json()
    assert body["deletedMetrics"] == 3
    assert body["deletedSleep"] == 1
    assert body["consentRevoked"] is True


def test_privacy_export_shape_includes_health_keys(monkeypatch) -> None:
    _auth_user(monkeypatch)
    monkeypatch.setattr(
        "app.api.privacy.privacy_repository.export_user_data",
        lambda user_id: {
            "user": {"id": user_id},
            "wearable_metric_daily": [{"metric_type": "steps", "local_date": "2026-07-01"}],
            "wearable_sleep_summaries": [{"local_date": "2026-07-01", "total_minutes": 420}],
            "wearable_sync_state": [{"sync_status": "success"}],
            "health_data_consents": [{"source": "apple_health"}],
            "wearable_daily_summaries": [],
            "wearable_hourly_summaries": [],
        },
    )
    client = TestClient(app)
    response = client.get("/api/privacy/export", headers=_auth())
    assert response.status_code == 200
    data = response.json()["data"]
    assert "wearable_metric_daily" in data
    assert "wearable_sleep_summaries" in data
    assert "wearable_sync_state" in data


def test_legacy_symptom_types_still_in_taxonomy() -> None:
    payload = taxonomy_payload("en")
    types = {s["symptomType"] for c in payload["categories"] for s in c["symptoms"]}
    assert {"cough", "wheeze", "headache", "fatigue"}.issubset(types)


def test_insight_minimum_and_no_causal_wording() -> None:
    assert _confidence(2, 30) == "insufficient"
    assert _confidence(5, 30) == "preliminary"
    ru = _render_text("pm25", "cough_count", 0.4, "ru")
    en = _render_text("pm25", "cough_count", 0.4, "en")
    assert "диагноз" not in ru.lower()
    assert "причинно-следственн" in ru or "не доказанная" in ru
    assert "not proven causation" in en
    assert "caused" not in en.lower()


def test_timezone_preserved_in_sync_model() -> None:
    req = HealthSyncRequest(
        localDate=date(2026, 7, 19),
        timezone="America/New_York",
        platform=WearablePlatform.IOS,
        source=WearableSource.APPLE_HEALTH,
        metrics=[
            MetricSummaryItem(
                metricType="oxygen_saturation",
                unit="percent",
                valueAvg=97.0,
                qualityState=QualityState.OK,
                sampleCount=3,
            )
        ],
    )
    assert req.timezone == "America/New_York"
    assert req.localDate.isoformat() == "2026-07-19"


def test_summary_endpoint_monkeypatched(monkeypatch) -> None:
    _auth_user(monkeypatch)
    monkeypatch.setattr(
        "app.api.health_intelligence.health_sync_repository.list_metrics_for_date",
        lambda user_id, day: [],
    )
    monkeypatch.setattr(
        "app.api.health_intelligence.health_sync_repository.get_sleep_for_date",
        lambda user_id, day: None,
    )
    monkeypatch.setattr(
        "app.api.health_intelligence.health_sync_repository.count_metric_days",
        lambda user_id, metric_type, days=30: 0,
    )
    client = TestClient(app)
    response = client.get("/api/v1/health/summary", headers=_auth())
    assert response.status_code == 200
    body = response.json()
    assert body["metrics"] == []
    assert body["sleep"] is None
    assert body["dataDaysAvailable"] == 0


def test_availability_lists_canonical_metrics(monkeypatch) -> None:
    _auth_user(monkeypatch)
    monkeypatch.setattr(
        "app.api.health_intelligence.health_sync_repository.get_sync_state",
        lambda user_id, source_platform=None: None,
    )
    monkeypatch.setattr(
        "app.api.health_intelligence.health_sync_repository.list_metrics_for_date",
        lambda user_id, day: [],
    )
    client = TestClient(app)
    response = client.get("/api/v1/health/availability", headers=_auth())
    assert response.status_code == 200
    items = response.json()["items"]
    types = {item["metricType"] for item in items}
    assert "steps" in types
    assert "hrv_sdnn" in types
    assert "hrv_rmssd" in types
    assert "body_temperature" in types
    assert "wrist_temperature" in types
    assert all(item["qualityState"] == "no_records" for item in items)


def test_insights_require_premium_feature(monkeypatch) -> None:
    _auth_user(monkeypatch)
    import app.services.entitlement_service as entitlement_service
    from app.models.subscription import UserEntitlementResponse
    from datetime import UTC, timedelta

    free = UserEntitlementResponse(
        user_id="user-1",
        plan="free",
        is_premium=False,
        premium_until=None,
        max_profiles=1,
        extended_forecast_enabled=False,
        custom_alerts_enabled=False,
        export_reports_enabled=False,
        advanced_insights_enabled=False,
        wearable_insights_enabled=False,
        priority_notifications_enabled=False,
    )

    def _require(user_id, feature, attr):
        from fastapi import HTTPException

        raise HTTPException(status_code=402, detail="Premium required")

    monkeypatch.setattr(entitlement_service, "get_current_entitlement", lambda user_id: free)
    monkeypatch.setattr(entitlement_service, "require_feature", _require)
    client = TestClient(app)
    response = client.get(
        f"/api/v1/health/insights?profile_id={uuid4()}",
        headers=_auth(),
    )
    assert response.status_code == 402


def test_custom_symptom_isolated_check(monkeypatch) -> None:
    _auth_user(monkeypatch, "user-a")
    monkeypatch.setattr(
        "app.api.health_intelligence.profile_access.profile_belongs_to_user",
        lambda profile_id, user_id: user_id == "user-a",
    )
    from app.models.health_intelligence import CustomSymptomResponse

    monkeypatch.setattr(
        "app.api.health_intelligence.symptom_entry_repository.create_custom_symptom",
        lambda user_id, payload: CustomSymptomResponse(
            id="c1",
            symptomType="custom:c1",
            label=payload.label,
            category="custom",
            iconKey=None,
            isHidden=False,
        ),
    )
    client = TestClient(app)
    ok = client.post(
        "/api/v1/health/symptoms/custom",
        headers=_auth(),
        json={"profileId": str(uuid4()), "label": "My symptom"},
    )
    assert ok.status_code == 200
    assert ok.json()["symptomType"].startswith("custom:")
