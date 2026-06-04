from datetime import datetime, timezone

from fastapi.testclient import TestClient

import app.api.deps as deps
from app.main import app
from app.models.air import (
    AlertDecision,
    AlertSeverity,
    AlertType,
    ProfileType,
    RecommendationCard,
    RiskAssessmentResult,
    RiskLevel,
    SafeWindow,
    SafeWindowType,
    SymptomHistoryItem,
    UserProfileContext,
)
from app.models.briefing import BriefingScheduleResponse
from app.models.risk import EnvironmentSnapshot
from app.models.settings import UserSettingsResponse
from app.models.user import ProfileCreateRequest, ProfileResponse


def _auth_headers() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def _enable_auth(monkeypatch, user_id: str = "user-1") -> None:
    monkeypatch.setattr(deps, "decode_access_token", lambda token: user_id)
    monkeypatch.setattr(deps.user_repository, "user_exists", lambda _user_id: True)


def _profile(user_id: str = "user-1") -> UserProfileContext:
    return UserProfileContext(
        profile_id="profile-1",
        user_id=user_id,
        profile_type=ProfileType.ADULT_DEFAULT,
        timezone="UTC",
        home_lat=41.39,
        home_lon=2.17,
    )


def _risk() -> RiskAssessmentResult:
    return RiskAssessmentResult(
        overallRisk=RiskLevel.MODERATE,
        heatRisk=RiskLevel.MODERATE,
        airRisk=RiskLevel.LOW,
        outdoorRisk=RiskLevel.MODERATE,
        indoorVentilationRisk=RiskLevel.LOW,
        safeWindows=[
            SafeWindow(
                type=SafeWindowType.WALK,
                start="2026-05-20T16:00:00Z",
                end="2026-05-20T18:00:00Z",
                confidence=0.85,
            )
        ],
        recommendationFlags=["hydrate"],
        reasonCodes=["moderate_heat"],
    )


def _recommendation() -> RecommendationCard:
    return RecommendationCard(
        headline="Plan carefully",
        summary="Conditions are manageable.",
        actions=["Hydrate", "Avoid peak heat"],
    )


def test_profiles_create_and_list(monkeypatch) -> None:
    _enable_auth(monkeypatch)
    payload = ProfileCreateRequest(
        persona_type="adult",
        sensitivity_level="medium",
        home_lat=41.39,
        home_lon=2.17,
    )
    created = ProfileResponse.create("user-1", payload)
    monkeypatch.setattr("app.api.profiles.user_repository.create_profile", lambda user_id, payload: created)
    monkeypatch.setattr("app.api.profiles.user_repository.list_profiles", lambda user_id: [created])

    client = TestClient(app)
    create_response = client.post("/api/profiles", json=payload.model_dump(), headers=_auth_headers())
    list_response = client.get("/api/profiles", headers=_auth_headers())
    assert create_response.status_code == 200
    assert list_response.status_code == 200
    assert list_response.json()[0]["id"] == created.id


def test_settings_get_and_update(monkeypatch) -> None:
    _enable_auth(monkeypatch)
    settings = UserSettingsResponse(
        user_id="user-1",
        push_alerts_enabled=True,
        alert_threshold="medium",
        default_persona="adult",
        quiet_hours_start=22,
        quiet_hours_end=7,
        profile_based_alerting=True,
        preferred_language="ru",
    )
    monkeypatch.setattr("app.api.settings.settings_repository.get_user_settings", lambda user_id: settings)
    monkeypatch.setattr(
        "app.api.settings.settings_repository.upsert_user_settings",
        lambda user_id, payload: settings,
    )
    client = TestClient(app)
    get_response = client.get("/api/settings", headers=_auth_headers())
    put_response = client.put(
        "/api/settings",
        json={
            "push_alerts_enabled": True,
            "alert_threshold": "medium",
            "default_persona": "adult",
            "quiet_hours_start": 22,
            "quiet_hours_end": 7,
            "profile_based_alerting": True,
            "preferred_language": "ru",
        },
        headers=_auth_headers(),
    )
    assert get_response.status_code == 200
    assert put_response.status_code == 200


def test_symptoms_endpoints(monkeypatch) -> None:
    _enable_auth(monkeypatch)
    monkeypatch.setattr("app.api.symptoms.profile_access.profile_exists", lambda profile_id: True)
    monkeypatch.setattr("app.api.symptoms.profile_access.profile_belongs_to_user", lambda profile_id, user_id: True)
    monkeypatch.setattr(
        "app.api.symptoms.risk_repository.create_symptom_log",
        lambda profile_id, symptom: {
            "id": "sym-log-1",
            "profile_id": profile_id,
            "timestamp_utc": "2026-05-21T08:00:00Z",
        },
    )
    monkeypatch.setattr(
        "app.api.symptoms.air_repository.create_symptom_entry",
        lambda profile_id, symptom_type, intensity, note: SymptomHistoryItem(
            id="sym-quick-1",
            profileId=profile_id,
            symptomType=symptom_type,
            intensity=intensity,
            note=note,
            loggedAt="2026-05-21T08:00:00Z",
        ),
    )
    monkeypatch.setattr(
        "app.api.symptoms.air_repository.get_symptom_history",
        lambda profile_id: [
            SymptomHistoryItem(
                id="sym-quick-1",
                profileId=profile_id,
                symptomType="cough",
                intensity=3,
                note=None,
                loggedAt="2026-05-21T08:00:00Z",
            )
        ],
    )

    client = TestClient(app)
    log_response = client.post(
        "/api/symptoms/log",
        json={
            "profile_id": "profile-1",
            "symptom": {
                "cough": True,
                "wheeze": False,
                "headache": False,
                "fatigue": False,
                "sleep_quality": 3,
            },
        },
        headers=_auth_headers(),
    )
    quick_response = client.post(
        "/api/symptoms",
        json={"profileId": "profile-1", "symptomType": "cough", "intensity": 3, "note": "mild"},
        headers=_auth_headers(),
    )
    history_response = client.get("/api/symptoms/history", params={"profileId": "profile-1"}, headers=_auth_headers())
    assert log_response.status_code == 200
    assert quick_response.status_code == 200
    assert history_response.status_code == 200


def test_recommendations_daily(monkeypatch) -> None:
    _enable_auth(monkeypatch)
    monkeypatch.setattr("app.api.recommendations.profile_access.profile_exists", lambda profile_id: True)
    monkeypatch.setattr(
        "app.api.recommendations.profile_access.profile_belongs_to_user",
        lambda profile_id, user_id: True,
    )
    monkeypatch.setattr(
        "app.api.recommendations.entitlement_service.require_feature",
        lambda user_id, feature, attr: None,
    )
    monkeypatch.setattr(
        "app.api.recommendations.risk_repository.get_risk_history",
        lambda profile_id, limit: [{"risk_level": "moderate"}],
    )
    monkeypatch.setattr(
        "app.api.recommendations.risk_repository.get_recent_symptom_stats",
        lambda profile_id, hours: {"cough_count": 1},
    )
    monkeypatch.setattr(
        "app.api.recommendations.recommendation_service.build_daily_recommendation",
        lambda risk_level, symptom_stats: ("Daily summary", ["Action A"]),
    )

    client = TestClient(app)
    response = client.get("/api/recommendations/daily", params={"profile_id": "profile-1"}, headers=_auth_headers())
    assert response.status_code == 200
    assert response.json()["risk_level"] == "moderate"


def test_privacy_endpoints(monkeypatch) -> None:
    _enable_auth(monkeypatch)
    monkeypatch.setattr(
        "app.api.privacy.entitlement_service.require_feature",
        lambda user_id, feature, attr: None,
    )
    monkeypatch.setattr("app.api.privacy.privacy_repository.export_user_data", lambda user_id: {"items": []})
    monkeypatch.setattr("app.api.privacy.privacy_repository.delete_user_data", lambda user_id: True)
    client = TestClient(app)
    export_response = client.get("/api/privacy/export", headers=_auth_headers())
    delete_response = client.post(
        "/api/privacy/delete-account",
        json={"confirmation": "DELETE"},
        headers=_auth_headers(),
    )
    assert export_response.status_code == 200
    assert delete_response.status_code == 200


def test_alerts_evaluate(monkeypatch) -> None:
    _enable_auth(monkeypatch)
    monkeypatch.setattr("app.api.alerts.air_repository.get_profile_context", lambda profile_id: _profile())
    monkeypatch.setattr(
        "app.api.alerts.settings_repository.get_user_settings",
        lambda user_id: UserSettingsResponse(
            user_id=user_id,
            push_alerts_enabled=True,
            alert_threshold="medium",
            default_persona="adult",
            quiet_hours_start=22,
            quiet_hours_end=7,
            profile_based_alerting=True,
            preferred_language="ru",
        ),
    )
    monkeypatch.setattr(
        "app.api.alerts.alert_orchestrator.evaluate_alert",
        lambda profile, risk, recommendation, language: AlertDecision(
            shouldSend=True,
            alertType=AlertType.RISK_INCREASE,
            severity=AlertSeverity.MEDIUM,
            title="Alert",
            body="Risk increased",
            dedupeKey="dedupe-1",
            reason="test",
        ),
    )
    monkeypatch.setattr("app.api.alerts.air_repository.save_alert_event", lambda **kwargs: "evt-1")
    monkeypatch.setattr("app.api.alerts.notification_repository.list_active_device_targets", lambda user_id: [])
    monkeypatch.setattr(
        "app.api.alerts.notification_dispatcher.dispatch_stub",
        lambda user_id, profile_id, risk_level, message, device_targets, force_send: (0, True, "not_dispatched", None, None),
    )

    client = TestClient(app)
    response = client.post(
        "/api/alerts/evaluate",
        json={
            "profileId": "profile-1",
            "risk": _risk().model_dump(),
            "recommendation": _recommendation().model_dump(),
        },
        headers=_auth_headers(),
    )
    assert response.status_code == 200
    assert response.json()["decision"]["shouldSend"] is True


def test_briefings_schedule(monkeypatch) -> None:
    _enable_auth(monkeypatch)
    schedule = BriefingScheduleResponse(
        user_id="user-1",
        local_time="07:30",
        timezone="UTC",
        enabled=True,
        last_sent_at=None,
    )
    monkeypatch.setattr("app.api.briefings.briefing_repository.get_user_profile_ids", lambda user_id: ["profile-1"])
    monkeypatch.setattr("app.api.briefings.air_repository.get_profile_context", lambda profile_id: _profile())
    monkeypatch.setattr("app.api.briefings.briefing_repository.get_schedule", lambda user_id, timezone: schedule)
    monkeypatch.setattr("app.api.briefings.briefing_repository.upsert_schedule", lambda user_id, payload, timezone: schedule)

    client = TestClient(app)
    get_response = client.get("/api/briefings/schedule", headers=_auth_headers())
    put_response = client.put("/api/briefings/schedule", json={"local_time": "07:30", "enabled": True}, headers=_auth_headers())
    assert get_response.status_code == 200
    assert put_response.status_code == 200


def test_insights_personal_patterns(monkeypatch) -> None:
    _enable_auth(monkeypatch)
    monkeypatch.setattr("app.api.insights.air_repository.get_profile_context", lambda profile_id: _profile())
    monkeypatch.setattr("app.api.insights.insights_repository.get_daily_correlation_samples", lambda profile_id, window_days: [])

    pattern = type(
        "Pattern",
        (),
        {
            "factorA": "heat",
            "factorB": "fatigue",
            "coefficient": 0.5,
            "pValue": 0.03,
            "sampleSize": 30,
            "humanReadableText": "Heat correlates with fatigue.",
        },
    )()
    monkeypatch.setattr("app.api.insights.correlation_engine.compute_personal_patterns", lambda samples, language: [pattern])
    monkeypatch.setattr("app.api.insights.insights_repository.replace_personal_correlations", lambda profile_id, window_days, items: None)
    monkeypatch.setattr(
        "app.api.insights.correlation_engine.now_utc_iso",
        lambda: datetime.now(timezone.utc).isoformat(),
    )

    client = TestClient(app)
    response = client.get(
        "/api/insights/personal-patterns",
        params={"profile_id": "profile-1", "window_days": 30, "language": "ru"},
        headers=_auth_headers(),
    )
    assert response.status_code == 200
    assert response.json()["profileId"] == "profile-1"


def test_planner_and_validation(monkeypatch) -> None:
    _enable_auth(monkeypatch)
    monkeypatch.setattr(
        "app.api.planner.build_mock_snapshot",
        lambda lat, lon: EnvironmentSnapshot(
            temperature_c=26.0,
            humidity_percent=55.0,
            aqi=60,
            pm25=11.0,
            ozone=62.0,
            source="mock",
        ),
    )
    monkeypatch.setattr(
        "app.api.planner.air_risk_engine.evaluate_risk",
        lambda profile, environment: RiskAssessmentResult(
            overallRisk=RiskLevel.LOW,
            heatRisk=RiskLevel.LOW,
            airRisk=RiskLevel.LOW,
            outdoorRisk=RiskLevel.LOW,
            indoorVentilationRisk=RiskLevel.LOW,
            safeWindows=[],
            recommendationFlags=[],
            reasonCodes=[],
        ),
    )
    monkeypatch.setattr(
        "app.api.validation.run_historical_validation",
        lambda: {
            "passed": True,
            "total_cases": 1,
            "passed_cases": 1,
            "failed_case_ids": [],
            "cases": [
                {
                    "case_id": "case-1",
                    "score": 20,
                    "level": "low",
                    "expected_min_level": "low",
                    "passed": True,
                }
            ],
        },
    )
    client = TestClient(app)
    planner_response = client.get("/api/planner/daily", headers=_auth_headers())
    validation_response = client.get("/api/validation/risk/historical")
    assert planner_response.status_code == 200
    assert validation_response.status_code == 200


def test_legacy_risk_endpoints_return_deprecation_headers(monkeypatch) -> None:
    _enable_auth(monkeypatch)
    monkeypatch.setattr(
        "app.api.risk.estimate_risk",
        lambda persona, symptoms, environment: (35, "medium", ["Hydrate"], {"env_component": 20}),
    )
    monkeypatch.setattr("app.api.risk.profile_access.profile_exists", lambda profile_id: True)
    monkeypatch.setattr("app.api.risk.profile_access.profile_belongs_to_user", lambda profile_id, user_id: True)
    monkeypatch.setattr(
        "app.api.risk.risk_repository.get_risk_history",
        lambda profile_id, limit: [
            {
                "id": "risk-1",
                "profile_id": profile_id,
                "score_value": 40,
                "risk_level": "medium",
                "recommendations": ["Hydrate"],
                "created_at": "2026-05-21T09:00:00Z",
            }
        ],
    )

    client = TestClient(app)
    estimate = client.post(
        "/api/risk/estimate",
        json={
            "persona": "adult",
            "symptoms": {"cough": False, "wheeze": False, "headache": False, "fatigue": False, "sleep_quality": 3},
            "environment": {
                "temperature_c": 26.0,
                "humidity_percent": 55.0,
                "aqi": 60,
                "pm25": 11.0,
                "ozone": 62.0,
                "source": "mock",
            },
        },
        headers=_auth_headers(),
    )
    history = client.get("/api/risk/history", params={"profile_id": "profile-1"}, headers=_auth_headers())
    thresholds = client.get("/api/risk/thresholds")
    assert estimate.status_code == 200
    assert history.status_code == 200
    assert thresholds.status_code == 200
    assert estimate.headers.get("Deprecation") == "true"
    assert history.headers.get("Deprecation") == "true"
    assert thresholds.headers.get("Deprecation") == "true"
