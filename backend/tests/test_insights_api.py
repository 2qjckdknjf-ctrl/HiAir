from fastapi.testclient import TestClient

from app.api import insights as insights_api
from app.api.deps import get_current_user_id
from app.main import app
from app.models.air import EnvironmentalInput, ProfileType, UserProfileContext
from app.models.risk import EnvironmentSnapshot, PersonaType, SymptomInput
from app.services.risk_breakdown_service import build_risk_breakdown

client = TestClient(app)


def test_profile_risk_breakdown_uses_profile_environment(monkeypatch) -> None:
    profile = UserProfileContext(
        profile_id="profile-1",
        user_id="user-1",
        profile_type=ProfileType.ADULT_DEFAULT,
        home_lat=51.5,
        home_lon=-0.1,
    )
    environment = EnvironmentalInput(
        lat=51.5,
        lon=-0.1,
        temperature=40.0,
        feels_like=43.0,
        humidity=82.0,
        aqi=190,
        pm25=65.0,
        pm10=94.0,
        ozone=120.0,
        uv=8.0,
        wind_speed=2.3,
        source="profile-env",
        timestamp="2026-06-20T12:00:00+00:00",
        timezone="UTC",
    )
    monkeypatch.setattr(insights_api.air_repository, "get_profile_context", lambda _profile_id: profile)
    monkeypatch.setattr(
        insights_api.air_environment_service,
        "load_environment",
        lambda _profile, force_live: environment,
    )
    monkeypatch.setattr(
        insights_api.risk_repository,
        "get_recent_symptom_stats",
        lambda profile_id, hours: {
            "cough_count": 0,
            "wheeze_count": 0,
            "headache_count": 0,
            "fatigue_count": 0,
            "total_logs": 0,
        },
    )
    monkeypatch.setattr(insights_api.risk_repository, "get_latest_sleep_quality", lambda profile_id: 3)
    monkeypatch.setattr(insights_api.wearable_repository, "get_latest_metrics", lambda user_id, profile_id: None)

    expected = build_risk_breakdown(
        profile_id="profile-1",
        persona=PersonaType.ADULT,
        symptoms=SymptomInput(),
        environment=EnvironmentSnapshot(
            temperature_c=environment.temperature,
            humidity_percent=environment.humidity,
            aqi=environment.aqi,
            pm25=environment.pm25,
            ozone=environment.ozone,
            source=environment.source,
        ),
        wearable=None,
    )

    app.dependency_overrides[get_current_user_id] = lambda: "user-1"
    try:
        response = client.get(
            "/api/insights/risk-breakdown",
            params={"profile_id": "profile-1", "persona": "adult", "lat": 0.0, "lon": 0.0},
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    body = response.json()
    assert body["total_score"] == expected.total_score
    assert body["risk_level"] == expected.risk_level
