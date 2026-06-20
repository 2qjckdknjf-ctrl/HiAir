from app.models.risk import EnvironmentSnapshot, PersonaType, SymptomInput
from app.services.risk_breakdown_service import build_risk_breakdown


def test_risk_breakdown_factors_sum_to_total() -> None:
    environment = EnvironmentSnapshot(
        temperature_c=36.0,
        humidity_percent=78.0,
        aqi=120,
        pm25=40.0,
        ozone=95.0,
        source="mock",
    )
    symptoms = SymptomInput(cough=True, sleep_quality=2)
    breakdown = build_risk_breakdown(
        profile_id="profile-1",
        persona=PersonaType.ASTHMA,
        symptoms=symptoms,
        environment=environment,
    )
    factor_sum = sum(f.points for f in breakdown.factors)
    assert breakdown.total_score == min(100, factor_sum)
    assert breakdown.total_score >= 35
    assert any(f.key == "heat" for f in breakdown.factors)
    assert any(f.key == "pm25" for f in breakdown.factors)


def test_risk_breakdown_hides_zero_factors() -> None:
    environment = EnvironmentSnapshot(
        temperature_c=20.0,
        humidity_percent=40.0,
        aqi=20,
        pm25=5.0,
        ozone=10.0,
        source="mock",
    )
    breakdown = build_risk_breakdown(
        profile_id=None,
        persona=PersonaType.ADULT,
        symptoms=SymptomInput(),
        environment=environment,
    )
    assert all(f.points > 0 for f in breakdown.factors)
    assert breakdown.risk_level == "low"
