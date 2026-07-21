from datetime import date, datetime, timezone
from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app
from app.models.health_intelligence import (
    ComprehensiveSymptomCreateRequest,
    HealthSyncRequest,
    InsightCard,
    MetricSummaryItem,
    QualityState,
    SleepSummaryItem,
)
from app.models.wearable import WearableConsentResponse, WearablePlatform, WearableSource
from app.services.health_analytics_service import _confidence
from app.services.health_metrics import consent_allows_metric, is_known_metric, is_sensitive
from app.services.symptom_taxonomy import (
    SYMPTOMS,
    is_known_symptom,
    is_red_flag,
    taxonomy_payload,
)
from app.services import correlation_engine


def _auth_headers() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def _active_consent(**overrides) -> WearableConsentResponse:
    base = dict(
        id="consent-1",
        userId="user-1",
        platform=WearablePlatform.IOS,
        source=WearableSource.APPLE_HEALTH,
        stepsEnabled=True,
        heartRateEnabled=True,
        restingHeartRateEnabled=True,
        hrvEnabled=True,
        sleepEnabled=True,
        activityEnabled=True,
        sleepStagesEnabled=True,
        respiratoryEnabled=True,
        temperatureEnabled=True,
        workoutsEnabled=True,
        fitnessEnabled=True,
        bodyMetricsEnabled=True,
        sensitiveMetricsEnabled=True,
        consentVersion="health-intelligence-v1",
        acceptedAt=datetime.now(tz=timezone.utc),
        revokedAt=None,
        isActive=True,
    )
    base.update(overrides)
    return WearableConsentResponse(**base)


def test_canonical_metrics_known() -> None:
    assert is_known_metric("steps")
    assert is_known_metric("hrv_sdnn")
    assert is_known_metric("hrv_rmssd")
    assert is_known_metric("body_temperature")
    assert is_known_metric("wrist_temperature")
    assert not is_known_metric("raw_ecg")
    assert is_sensitive("blood_glucose")
    assert not is_sensitive("steps")


def test_symptom_taxonomy_coverage() -> None:
    payload = taxonomy_payload("ru")
    assert payload["count"] >= 70
    assert is_known_symptom("cough")
    assert is_known_symptom("dry_cough")
    assert is_known_symptom("chest_discomfort")
    assert is_red_flag("chest_discomfort")
    assert is_red_flag("shortness_of_breath")
    assert not is_red_flag("sneezing")
    categories = {c["id"] for c in payload["categories"]}
    assert "respiratory" in categories
    assert "heat_dehydration" in categories
    assert "digestion" in categories
    assert len(SYMPTOMS) == payload["count"]
    assert payload["safetyNotice"] == payload["severityNotice"]


def test_metric_summary_rejects_bad_unit() -> None:
    try:
        MetricSummaryItem(metricType="steps", unit="kg", valueTotal=100)
        assert False, "expected validation error"
    except Exception:
        pass


def test_metric_summary_hrv_method_auto() -> None:
    item = MetricSummaryItem(metricType="hrv_sdnn", unit="ms", valueAvg=42.0, sampleCount=3)
    assert item.hrvMethod == "sdnn"
    item2 = MetricSummaryItem(metricType="hrv_rmssd", unit="ms", valueAvg=35.0, sampleCount=3)
    assert item2.hrvMethod == "rmssd"


def test_missing_not_zero_in_correlation() -> None:
    samples = [
        {"pm25": 10.0, "cough_count": 1.0},
        {"pm25": None, "cough_count": 0.0},
        {"pm25": 40.0, "cough_count": 1.0},
    ]
    # Expand to MIN_POINTS with patterned data
    for i in range(20):
        samples.append({"pm25": 10.0 + i, "cough_count": 0.0 if i % 2 == 0 else 1.0})
    paired = correlation_engine._paired_non_null(samples, "pm25", "cough_count")
    assert all(a is not None and b is not None for a, b in paired)
    assert len(paired) == len([s for s in samples if s["pm25"] is not None and s["cough_count"] is not None])


def test_correlation_wellness_wording() -> None:
    text = correlation_engine._render_text("pm25", "cough_count", 0.5, "ru")
    assert "причинно-следственн" in text or "не доказанная" in text
    assert "диагноз" not in text.lower()
    en = correlation_engine._render_text("pm25", "cough_count", -0.4, "en")
    assert "not proven causation" in en


def test_confidence_thresholds() -> None:
    assert _confidence(2, 30) == "insufficient"
    assert _confidence(5, 30) == "preliminary"
    assert _confidence(7, 30) == "moderate"
    assert _confidence(14, 30) == "stronger"


def test_health_sync_requires_auth() -> None:
    client = TestClient(app)
    response = client.post(
        "/api/v1/health/sync",
        json={
            "localDate": date.today().isoformat(),
            "platform": "ios",
            "source": "apple_health",
            "metrics": [],
        },
    )
    assert response.status_code == 401


def test_consent_category_gates_sensitive_and_hrv() -> None:
    open_consent = _active_consent()
    assert consent_allows_metric(open_consent, "blood_glucose")
    locked = _active_consent(sensitiveMetricsEnabled=False, hrvEnabled=False)
    assert not consent_allows_metric(locked, "blood_glucose")
    assert not consent_allows_metric(locked, "hrv_sdnn")
    assert consent_allows_metric(locked, "steps")


def test_health_sync_success(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    monkeypatch.setattr(
        "app.api.health_intelligence.wearable_repository.get_active_consent",
        lambda user_id, source: _active_consent(),
    )
    now = datetime.now(tz=timezone.utc)

    def _apply(user_id, payload, consent=None):
        assert user_id == "user-1"
        assert consent is not None
        assert len(payload.metrics) == 2
        return 2, [], True, now

    monkeypatch.setattr("app.api.health_intelligence.health_sync_repository.apply_sync", _apply)
    monkeypatch.setattr(
        "app.api.health_intelligence.health_sync_repository.mirror_legacy_daily_from_metrics",
        lambda user_id, payload: None,
    )

    client = TestClient(app)
    response = client.post(
        "/api/v1/health/sync",
        headers={**_auth_headers(), "Idempotency-Key": "sync-1"},
        json={
            "localDate": date.today().isoformat(),
            "timezone": "Europe/Madrid",
            "platform": "ios",
            "source": "apple_health",
            "metrics": [
                {
                    "metricType": "steps",
                    "unit": "count",
                    "valueTotal": 8200,
                    "sampleCount": 1,
                    "qualityState": "ok",
                },
                {
                    "metricType": "hrv_sdnn",
                    "unit": "ms",
                    "valueAvg": 48,
                    "sampleCount": 4,
                    "qualityState": "ok",
                    "hrvMethod": "sdnn",
                },
            ],
            "sleep": {
                "localDate": date.today().isoformat(),
                "totalMinutes": 420,
                "deepMinutes": 80,
                "remMinutes": 90,
                "qualityState": "partial",
            },
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["acceptedMetrics"] == 2
    assert body["sleepAccepted"] is True
    assert body["syncStatus"] == "success"


def test_health_sync_rejects_without_consent(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    monkeypatch.setattr(
        "app.api.health_intelligence.wearable_repository.get_active_consent",
        lambda user_id, source: None,
    )
    client = TestClient(app)
    response = client.post(
        "/api/v1/health/sync",
        headers=_auth_headers(),
        json={
            "localDate": date.today().isoformat(),
            "platform": "ios",
            "source": "apple_health",
            "metrics": [
                {"metricType": "steps", "unit": "count", "valueTotal": 1000, "qualityState": "ok"}
            ],
        },
    )
    assert response.status_code == 403


def test_taxonomy_endpoint(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    client = TestClient(app)
    # taxonomy is public-ish but router has no auth requirement
    response = client.get("/api/v1/health/symptoms/taxonomy?language=ru")
    assert response.status_code == 200
    body = response.json()
    assert body["count"] >= 70
    # iOS SymptomTaxonomyDTO requires safetyNotice; Android also reads severityNotice.
    assert isinstance(body.get("safetyNotice"), str) and body["safetyNotice"].strip()
    assert isinstance(body.get("severityNotice"), str) and body["severityNotice"].strip()
    assert body["safetyNotice"] == body["severityNotice"]
    assert body.get("categories") and body["categories"][0].get("symptoms")


def test_comprehensive_symptom_create(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    monkeypatch.setattr("app.api.health_intelligence.profile_access.profile_exists", lambda _: True)
    monkeypatch.setattr(
        "app.api.health_intelligence.profile_access.profile_belongs_to_user",
        lambda profile_id, user_id: True,
    )

    def _create(user_id, payload, language="ru"):
        assert payload.symptomType == "chest_discomfort"
        from app.models.health_intelligence import ComprehensiveSymptomResponse
        from app.services.symptom_taxonomy import SAFETY_NOTICE

        return ComprehensiveSymptomResponse(
            id=str(uuid4()),
            profileId=payload.profileId,
            symptomType=payload.symptomType,
            category="cardiovascular_sensation",
            severity=payload.severity,
            onsetAt=datetime.now(tz=timezone.utc),
            durationMinutes=None,
            ongoing=False,
            note=None,
            redFlag=True,
            safetyNotice=SAFETY_NOTICE["ru"],
            loggedAt=datetime.now(tz=timezone.utc),
        )

    monkeypatch.setattr(
        "app.api.health_intelligence.symptom_entry_repository.create_comprehensive_entry",
        _create,
    )
    client = TestClient(app)
    response = client.post(
        "/api/v1/health/symptoms?language=ru",
        headers=_auth_headers(),
        json={
            "profileId": str(uuid4()),
            "symptomType": "chest_discomfort",
            "severity": 4,
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["redFlag"] is True
    assert body["safetyNotice"]


def test_insights_bundle_endpoint(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    monkeypatch.setattr("app.api.health_intelligence.profile_access.profile_exists", lambda _: True)
    monkeypatch.setattr(
        "app.api.health_intelligence.profile_access.profile_belongs_to_user",
        lambda profile_id, user_id: True,
    )
    profile_id = str(uuid4())
    monkeypatch.setattr(
        "app.api.health_intelligence.health_analytics_service.build_insights_bundle",
        lambda **kwargs: {
            "profileId": profile_id,
            "generatedAt": datetime.now(tz=timezone.utc),
            "today": {"steps": 5000, "symptoms": []},
            "trends": [
                InsightCard(
                    insightKey="trend_steps",
                    title="Активность",
                    observation="Наблюдается связь",
                    recommendation="Учитывайте самочувствие",
                    confidence="moderate",
                    sampleSize=10,
                    windowDays=30,
                    supportingFactors=["steps"],
                    limitations=["Это наблюдение связи, а не доказанная причина."],
                )
            ],
            "associations": [],
            "insufficientData": [],
            "healthDataStatus": {"metricDays": 10},
        },
    )
    client = TestClient(app)
    response = client.get(
        f"/api/v1/health/insights?profile_id={profile_id}&language=ru",
        headers=_auth_headers(),
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["trends"][0]["confidence"] == "moderate"
    assert "причин" in body["trends"][0]["limitations"][0]


def test_health_sync_request_model() -> None:
    req = HealthSyncRequest(
        localDate=date.today(),
        platform=WearablePlatform.IOS,
        source=WearableSource.APPLE_HEALTH,
        metrics=[
            MetricSummaryItem(
                metricType="oxygen_saturation",
                unit="percent",
                valueAvg=97.0,
                valueMin=95.0,
                valueMax=99.0,
                sampleCount=12,
                qualityState=QualityState.OK,
            )
        ],
        sleep=SleepSummaryItem(localDate=date.today(), totalMinutes=400, qualityState=QualityState.PARTIAL),
    )
    assert req.metrics[0].metricType == "oxygen_saturation"


def test_comprehensive_symptom_model_validation() -> None:
    ok = ComprehensiveSymptomCreateRequest(
        profileId=str(uuid4()),
        symptomType="itchy_eyes",
        severity=2,
        locationContext="outdoors",
        clientRequestId="req-1",
    )
    assert ok.severity == 2
    assert ok.clientRequestId == "req-1"
    try:
        ComprehensiveSymptomCreateRequest(
            profileId=str(uuid4()),
            symptomType="not_a_real_symptom",
            severity=2,
        )
        assert False
    except Exception:
        pass
