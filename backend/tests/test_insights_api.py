import app.api.insights as insights_api
from app.models.air import ProfileType, UserProfileContext
from app.models.insights import RiskBreakdownResponse
from app.models.risk import EnvironmentSnapshot, PersonaType


def test_risk_breakdown_uses_profile_persona(monkeypatch) -> None:
    profile = UserProfileContext(
        profile_id="profile-1",
        user_id="user-1",
        profile_type=ProfileType.ALLERGY_SENSITIVE,
    )
    monkeypatch.setattr(
        insights_api,
        "_resolve_profile",
        lambda *_args, **_kwargs: profile,
    )
    monkeypatch.setattr(
        insights_api,
        "build_mock_snapshot",
        lambda **_kwargs: EnvironmentSnapshot(
            temperature_c=24.0,
            humidity_percent=45.0,
            aqi=50,
            pm25=8.0,
            ozone=15.0,
            source="test",
        ),
    )
    monkeypatch.setattr(
        insights_api.risk_repository,
        "get_recent_symptom_stats",
        lambda **_kwargs: {
            "cough_count": 0,
            "wheeze_count": 0,
            "headache_count": 0,
            "fatigue_count": 0,
        },
    )
    monkeypatch.setattr(
        insights_api.risk_repository,
        "get_latest_sleep_quality",
        lambda **_kwargs: 3,
    )
    monkeypatch.setattr(
        insights_api.wearable_repository,
        "get_latest_metrics",
        lambda **_kwargs: None,
    )
    captured: dict[str, PersonaType] = {}

    def _fake_build_risk_breakdown(**kwargs) -> RiskBreakdownResponse:
        captured["persona"] = kwargs["persona"]
        return RiskBreakdownResponse(
            profile_id=kwargs["profile_id"],
            total_score=18,
            risk_level="low",
            factors=[],
        )

    monkeypatch.setattr(
        insights_api.risk_breakdown_service,
        "build_risk_breakdown",
        _fake_build_risk_breakdown,
    )

    response = insights_api.risk_breakdown(
        profile_id="profile-1",
        persona="adult",
        lat=41.39,
        lon=2.17,
        user_id="user-1",
    )

    assert response.profile_id == "profile-1"
    assert captured["persona"] == PersonaType.ALLERGY
