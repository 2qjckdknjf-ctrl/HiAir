import app.api.planner as planner_api
import app.services.morning_briefing_service as morning_briefing_service
from app.models.air import DayPlanResponse, HourlyRiskPoint, ProfileType, RiskLevel, UserProfileContext
from app.models.insights import RiskBreakdownResponse
from app.models.planner import DailyPlannerResponse, HourlyRiskItem
from app.models.risk import EnvironmentSnapshot, PersonaType, SymptomInput


def test_morning_briefing_guest_has_real_values() -> None:
    briefing = morning_briefing_service.build_morning_briefing_guest(
        persona=PersonaType.ADULT.value,
        lat=41.39,
        lon=2.17,
        language="ru",
    )
    assert briefing.risk_score >= 0
    assert briefing.temperature_c > 0
    assert briefing.aqi >= 0
    assert "риск" in briefing.summary.lower()
    assert briefing.personal_note != ""


def test_morning_briefing_guest_english() -> None:
    briefing = morning_briefing_service.build_morning_briefing_guest(
        persona="adult",
        lat=41.39,
        lon=2.17,
        language="en",
    )
    assert briefing.language == "en"
    assert "risk" in briefing.summary.lower()


def test_morning_briefing_guest_keeps_zero_score_and_contiguous_avoid_window(monkeypatch) -> None:
    monkeypatch.setattr(
        morning_briefing_service,
        "build_mock_snapshot",
        lambda **_kwargs: EnvironmentSnapshot(
            temperature_c=22.0,
            humidity_percent=40.0,
            aqi=20,
            pm25=5.0,
            ozone=10.0,
            source="test",
        ),
    )
    monkeypatch.setattr(
        morning_briefing_service,
        "estimate_risk",
        lambda **_kwargs: (0, "low", [], {}),
    )
    monkeypatch.setattr(
        morning_briefing_service,
        "build_risk_breakdown",
        lambda **_kwargs: RiskBreakdownResponse(
            profile_id=None,
            total_score=41,
            risk_level="medium",
            factors=[],
        ),
    )
    monkeypatch.setattr(
        planner_api,
        "daily_planner",
        lambda **_kwargs: DailyPlannerResponse(
            persona="adult",
            base_lat=41.39,
            base_lon=2.17,
            hourly=[
                HourlyRiskItem(hour_iso="2026-01-01T08:00:00+00:00", score=70, level="high"),
                HourlyRiskItem(hour_iso="2026-01-01T09:00:00+00:00", score=10, level="low"),
                HourlyRiskItem(hour_iso="2026-01-01T19:00:00+00:00", score=75, level="high"),
            ],
            safe_windows=[],
        ),
    )

    briefing = morning_briefing_service.build_morning_briefing_guest(
        persona="adult",
        lat=41.39,
        lon=2.17,
        language="en",
    )

    assert briefing.risk_score == 0
    assert briefing.avoid_outdoor_window == "08:00–08:00"


def test_profile_briefing_uses_breakdown_level(monkeypatch) -> None:
    profile = UserProfileContext(
        profile_id="profile-1",
        user_id="user-1",
        profile_type=ProfileType.OUTDOOR_WORKER,
    )
    monkeypatch.setattr(
        morning_briefing_service.air_environment_service,
        "load_environment",
        lambda *_args, **_kwargs: type(
            "Env",
            (),
            {
                "temperature": 30.0,
                "humidity": 50.0,
                "aqi": 90,
                "pm25": 15.0,
                "ozone": 40.0,
                "source": "test",
            },
        )(),
    )
    monkeypatch.setattr(
        morning_briefing_service.air_risk_engine,
        "build_day_plan",
        lambda *_args, **_kwargs: DayPlanResponse(
            profileId="profile-1",
            timezone="UTC",
            hourlyRisk=[
                HourlyRiskPoint(hour="2026-01-01T08:00:00+00:00", overallRisk=RiskLevel.HIGH),
                HourlyRiskPoint(hour="2026-01-01T09:00:00+00:00", overallRisk=RiskLevel.LOW),
            ],
            safeWindows=[],
            ventilationWindows=[],
        ),
    )
    monkeypatch.setattr(
        morning_briefing_service,
        "build_risk_breakdown",
        lambda **kwargs: RiskBreakdownResponse(
            profile_id=kwargs["profile_id"],
            total_score=55,
            risk_level="medium",
            factors=[],
        ),
    )
    monkeypatch.setattr(
        morning_briefing_service,
        "t",
        lambda _lang, key, default=None, **kwargs: kwargs.get("risk") or default or key,
    )

    briefing = morning_briefing_service.build_morning_briefing_for_profile(
        profile=profile,
        language="en",
        symptoms=SymptomInput(),
        wearable=None,
    )

    assert morning_briefing_service.persona_for_profile(profile) == PersonaType.WORKER
    assert briefing.risk_level == "medium"
    assert briefing.risk_score == 55
    assert "medium" in briefing.summary
