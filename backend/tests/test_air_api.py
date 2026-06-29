from fastapi.testclient import TestClient

import app.api.air as air_api
import app.api.deps as deps
from app.main import app
from app.models.air import (
    CurrentRiskResponse,
    DayPlanResponse,
    EnvironmentalInput,
    ProfileType,
    RecommendationCard,
    RiskAssessmentResult,
    RiskLevel,
    SafeWindow,
    SafeWindowType,
    UserProfileContext,
)


def _auth_headers() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def _sample_profile(user_id: str = "user-1") -> UserProfileContext:
    return UserProfileContext(
        profile_id="profile-1",
        user_id=user_id,
        profile_type=ProfileType.ADULT_DEFAULT,
        home_lat=41.39,
        home_lon=2.17,
    )


def _sample_environment() -> EnvironmentalInput:
    return EnvironmentalInput(
        lat=41.39,
        lon=2.17,
        temperature=26.0,
        feels_like=28.0,
        humidity=55.0,
        aqi=65,
        pm25=12.0,
        pm10=18.0,
        ozone=60.0,
        uv=5.0,
        wind_speed=2.1,
        source="mock",
        timestamp="2026-05-20T10:00:00Z",
        timezone="UTC",
    )


def _sample_risk() -> RiskAssessmentResult:
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
                end="2026-05-20T19:00:00Z",
                confidence=0.9,
            )
        ],
        recommendationFlags=["hydrate"],
        reasonCodes=["moderate_heat"],
    )


def _sample_recommendation() -> RecommendationCard:
    return RecommendationCard(
        headline="Plan outdoor time carefully",
        summary="Conditions are manageable with precautions.",
        actions=["Hydrate", "Prefer late afternoon"],
    )


def _enable_auth(monkeypatch) -> None:
    monkeypatch.setattr(deps, "decode_access_token", lambda token: "user-1")
    monkeypatch.setattr(deps.user_repository, "user_exists", lambda user_id: True)


def test_air_current_risk_returns_payload(monkeypatch) -> None:
    _enable_auth(monkeypatch)
    monkeypatch.setattr(
        air_api,
        "_compute_and_persist",
        lambda profile_id, user_id, force_live: CurrentRiskResponse(
            profileId=profile_id,
            assessedAt="2026-05-20T10:00:00Z",
            environmental=_sample_environment(),
            risk=_sample_risk(),
            recommendation=_sample_recommendation(),
            explanation="Use safer windows.",
            explanationSource="template",
        ),
    )

    client = TestClient(app)
    response = client.get("/api/air/current-risk", params={"profileId": "profile-1"}, headers=_auth_headers())
    assert response.status_code == 200
    body = response.json()
    assert body["profileId"] == "profile-1"
    assert body["risk"]["overallRisk"] == "moderate"


def test_air_day_plan_rejects_foreign_profile(monkeypatch) -> None:
    _enable_auth(monkeypatch)
    monkeypatch.setattr(air_api.air_repository, "get_profile_context", lambda profile_id: _sample_profile(user_id="user-2"))

    client = TestClient(app)
    response = client.get("/api/air/day-plan", params={"profileId": "profile-1"}, headers=_auth_headers())
    assert response.status_code == 403
    assert response.json()["detail"] == "Profile does not belong to user"


def test_air_day_plan_returns_payload(monkeypatch) -> None:
    _enable_auth(monkeypatch)
    monkeypatch.setattr(air_api.air_repository, "get_profile_context", lambda profile_id: _sample_profile())
    monkeypatch.setattr(air_api.air_environment_service, "load_environment", lambda profile, **kwargs: _sample_environment())
    monkeypatch.setattr(
        air_api.air_risk_engine,
        "build_day_plan",
        lambda profile, environment: DayPlanResponse(
            profileId=profile.profile_id,
            timezone=profile.timezone,
            hourlyRisk=[],
            safeWindows=[],
            ventilationWindows=[],
        ),
    )

    client = TestClient(app)
    response = client.get("/api/air/day-plan", params={"profileId": "profile-1"}, headers=_auth_headers())
    assert response.status_code == 200
    assert response.json()["profileId"] == "profile-1"


def test_air_recommendations_returns_payload(monkeypatch) -> None:
    _enable_auth(monkeypatch)
    monkeypatch.setattr(air_api.air_repository, "get_profile_context", lambda profile_id: _sample_profile())
    monkeypatch.setattr(
        air_api.settings_repository,
        "get_user_settings",
        lambda user_id: type("Settings", (), {"preferred_language": "en"})(),
    )
    monkeypatch.setattr(air_api.air_environment_service, "load_environment", lambda profile, **kwargs: _sample_environment())
    monkeypatch.setattr(
        air_api.air_risk_engine,
        "evaluate_risk",
        lambda profile, environment, personal_load=None: _sample_risk(),
    )
    monkeypatch.setattr(
        air_api.air_recommendation_engine,
        "generate_recommendation",
        lambda profile, risk, language: _sample_recommendation(),
    )

    client = TestClient(app)
    response = client.get("/api/air/recommendations", params={"profileId": "profile-1"}, headers=_auth_headers())
    assert response.status_code == 200
    body = response.json()
    assert body["profileId"] == "profile-1"
    assert body["recommendation"]["headline"]


def test_air_recompute_risk_uses_payload(monkeypatch) -> None:
    _enable_auth(monkeypatch)

    called = {}

    def _compute(profile_id: str, user_id: str, force_live: bool) -> CurrentRiskResponse:
        called["profile_id"] = profile_id
        called["force_live"] = force_live
        return CurrentRiskResponse(
            profileId=profile_id,
            assessedAt="2026-05-20T11:00:00Z",
            environmental=_sample_environment(),
            risk=_sample_risk(),
            recommendation=_sample_recommendation(),
            explanation="Recomputed.",
            explanationSource="template",
        )

    monkeypatch.setattr(air_api, "_compute_and_persist", _compute)

    client = TestClient(app)
    response = client.post(
        "/api/air/recompute-risk",
        json={"profileId": "profile-1", "forceRefresh": True},
        headers=_auth_headers(),
    )
    assert response.status_code == 200
    assert called["profile_id"] == "profile-1"
    assert called["force_live"] is True
