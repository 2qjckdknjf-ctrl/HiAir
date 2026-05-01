from app.models.risk import EnvironmentSnapshot, PersonaType, SymptomInput
from app.models.validation import HistoricalValidationCaseResult, HistoricalValidationResponse
from app.services.risk_engine import estimate_risk


_LEVEL_ORDER = {"low": 0, "moderate": 1, "high": 2, "very_high": 3}


def _passes(level: str, expected_min_level: str) -> bool:
    return _LEVEL_ORDER.get(level, -1) >= _LEVEL_ORDER.get(expected_min_level, 99)


def run_historical_validation() -> HistoricalValidationResponse:
    cases = [
        {
            "case_id": "heatwave_elderly",
            "persona": PersonaType.ELDERLY,
            "symptoms": SymptomInput(fatigue=True, sleep_quality=2),
            "environment": EnvironmentSnapshot(
                temperature_c=39.0,
                humidity_percent=72.0,
                aqi=85,
                pm25=20.0,
                ozone=95.0,
                source="historical",
            ),
            "expected_min_level": "high",
        },
        {
            "case_id": "pollution_asthma",
            "persona": PersonaType.ASTHMA,
            "symptoms": SymptomInput(cough=True, wheeze=True, sleep_quality=2),
            "environment": EnvironmentSnapshot(
                temperature_c=30.0,
                humidity_percent=60.0,
                aqi=180,
                pm25=62.0,
                ozone=122.0,
                source="historical",
            ),
            "expected_min_level": "very_high",
        },
        {
            "case_id": "mild_day_adult",
            "persona": PersonaType.ADULT,
            "symptoms": SymptomInput(),
            "environment": EnvironmentSnapshot(
                temperature_c=23.0,
                humidity_percent=42.0,
                aqi=35,
                pm25=8.0,
                ozone=35.0,
                source="historical",
            ),
            "expected_min_level": "low",
        },
        {
            "case_id": "runner_moderate_heat",
            "persona": PersonaType.RUNNER,
            "symptoms": SymptomInput(fatigue=True, sleep_quality=3),
            "environment": EnvironmentSnapshot(
                temperature_c=31.0,
                humidity_percent=58.0,
                aqi=90,
                pm25=22.0,
                ozone=75.0,
                source="historical",
            ),
            "expected_min_level": "moderate",
        },
    ]

    results: list[HistoricalValidationCaseResult] = []
    for case in cases:
        score, level, _, _ = estimate_risk(
            persona=case["persona"],
            symptoms=case["symptoms"],
            environment=case["environment"],
        )
        passed = _passes(level, case["expected_min_level"])
        results.append(
            HistoricalValidationCaseResult(
                case_id=case["case_id"],
                score=score,
                level=level,
                expected_min_level=case["expected_min_level"],
                passed=passed,
            )
        )

    failed_case_ids = [item.case_id for item in results if not item.passed]
    return HistoricalValidationResponse(
        passed=len(failed_case_ids) == 0,
        total_cases=len(results),
        passed_cases=len(results) - len(failed_case_ids),
        failed_case_ids=failed_case_ids,
        cases=results,
    )
