from datetime import UTC, date, datetime

import pytest

from app.services.personal_load_engine import (
    PersonalLoadInput,
    compute_personal_load_score,
    compute_weighted_final_score,
    environmental_numeric_score,
    personal_load_risk_bump,
)


def test_no_health_data_returns_zero_score() -> None:
    result = compute_personal_load_score(PersonalLoadInput(consent_active=False))
    assert result.score == 0
    assert result.level == "none"
    assert any("погоде" in e or "weather" in e.lower() or "Данных" in e for e in result.explanations)


def test_high_heat_and_high_steps() -> None:
    result = compute_personal_load_score(
        PersonalLoadInput(
            steps_today=10_500,
            heat_index=35,
            consent_active=True,
        )
    )
    assert result.score >= 20
    assert "high_steps_extreme_heat" in result.reason_codes
    assert any("жар" in e.lower() or "активност" in e.lower() for e in result.explanations)


def test_high_aqi_and_steps() -> None:
    result = compute_personal_load_score(
        PersonalLoadInput(
            steps_today=7_000,
            aqi=120,
            consent_active=True,
        )
    )
    assert result.score >= 10
    assert "elevated_air_high_activity" in result.reason_codes


def test_resting_hr_above_baseline() -> None:
    result = compute_personal_load_score(
        PersonalLoadInput(
            resting_heart_rate=78,
            resting_heart_rate_baseline_7d=68,
            consent_active=True,
        )
    )
    assert result.score >= 15
    assert "resting_hr_above_7d_baseline" in result.reason_codes


def test_high_hr_max_with_heat() -> None:
    result = compute_personal_load_score(
        PersonalLoadInput(
            heart_rate_max=145,
            heat_index=32,
            consent_active=True,
        )
    )
    assert result.score >= 10
    assert "elevated_hr_max_heat" in result.reason_codes


def test_consent_revoked_no_scoring() -> None:
    result = compute_personal_load_score(
        PersonalLoadInput(
            steps_today=12_000,
            heat_index=40,
            consent_active=False,
        )
    )
    assert result.score == 0


def test_no_medical_wording_in_explanations() -> None:
    result = compute_personal_load_score(
        PersonalLoadInput(
            heart_rate_max=160,
            heart_rate_avg=110,
            heat_index=38,
            aqi=180,
            steps_today=12_000,
            consent_active=True,
        )
    )
    joined = " ".join(result.explanations).lower()
    assert "тахикард" not in joined
    assert "больниц" not in joined
    assert "диагност" not in joined


def test_weighted_final_score_blend() -> None:
    final = compute_weighted_final_score(80, 40, 20)
    assert 50 <= final <= 70


def test_personal_load_risk_bump() -> None:
    assert personal_load_risk_bump(0) == 0
    assert personal_load_risk_bump(30) == 1
    assert personal_load_risk_bump(60) == 1


def test_environmental_numeric_score() -> None:
    score = environmental_numeric_score(feels_like=36, humidity=70, aqi=120, pm25=40, ozone=95)
    assert score > 30
