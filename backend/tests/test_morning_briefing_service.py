from app.models.risk import PersonaType, SymptomInput
from app.services.environment_service import build_mock_snapshot
from app.services.morning_briefing_service import build_morning_briefing_guest


def test_morning_briefing_guest_has_real_values() -> None:
    briefing = build_morning_briefing_guest(
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
    briefing = build_morning_briefing_guest(
        persona="adult",
        lat=41.39,
        lon=2.17,
        language="en",
    )
    assert briefing.language == "en"
    assert "risk" in briefing.summary.lower()
