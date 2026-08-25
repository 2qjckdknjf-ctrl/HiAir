"""Tests for HiAir 2.0 work / B2B occupational heat safety engine."""

from app.models.air import RiskLevel
from app.models.work_safety import WorkloadCategory, WorkSafetyEnvironmentInput
from app.services.work_safety_engine import assess_site_risk


def test_wbgt_present_uses_occupational_assessment() -> None:
    env = WorkSafetyEnvironmentInput(
        lat=25.20,
        lon=55.27,
        wbgt_c=29.5,
        heat_index_c=38.0,
    )
    result = assess_site_risk(env, WorkloadCategory.MODERATE, acclimatized=True)

    assert result.wbgtC == 29.5
    assert result.heatIndexC == 38.0
    assert "wbgt" in result.availableMetrics
    assert "wbgt_assessment" in result.reasonCodes
    assert "wbgt_unavailable" not in result.reasonCodes
    assert "heat_index_proxy_only" not in result.reasonCodes
    assert result.riskLevel == RiskLevel.HIGH
    assert result.workRest.workMinutes == 30
    assert result.workRest.restMinutes == 30
    assert "niosh_heuristic_v0" in result.workRest.rationaleCodes


def test_wbgt_missing_honest_proxy_fallback() -> None:
    env = WorkSafetyEnvironmentInput(
        lat=25.20,
        lon=55.27,
        wbgt_c=None,
        heat_index_c=33.0,
    )
    result = assess_site_risk(env, WorkloadCategory.MODERATE, acclimatized=True)

    assert result.wbgtC is None
    assert result.heatIndexC == 33.0
    assert "wbgt" in result.missingMetrics
    assert "heat_index" in result.availableMetrics
    assert "wbgt_unavailable" in result.reasonCodes
    assert "heat_index_proxy_only" in result.reasonCodes
    assert "wbgt_assessment" not in result.reasonCodes
    assert "heat_index_proxy_only" in result.workRest.rationaleCodes
    assert result.riskLevel == RiskLevel.HIGH


def test_wbgt_and_heat_index_missing() -> None:
    env = WorkSafetyEnvironmentInput(lat=25.20, lon=55.27, wbgt_c=None, heat_index_c=None)
    result = assess_site_risk(env, WorkloadCategory.HEAVY, acclimatized=False)

    assert result.wbgtC is None
    assert result.heatIndexC is None
    assert "wbgt_unavailable" in result.reasonCodes
    assert "heat_index_unavailable" in result.reasonCodes
    assert result.workRest.rationaleCodes == ["insufficient_heat_metrics"]
    assert result.workRest.workMinutes == 0


def test_work_rest_mapping_escalates_with_wbgt() -> None:
    low = assess_site_risk(
        WorkSafetyEnvironmentInput(lat=1.0, lon=1.0, wbgt_c=24.0, heat_index_c=30.0),
        WorkloadCategory.MODERATE,
    )
    moderate = assess_site_risk(
        WorkSafetyEnvironmentInput(lat=1.0, lon=1.0, wbgt_c=27.0, heat_index_c=30.0),
        WorkloadCategory.MODERATE,
    )
    very_high = assess_site_risk(
        WorkSafetyEnvironmentInput(lat=1.0, lon=1.0, wbgt_c=31.0, heat_index_c=30.0),
        WorkloadCategory.VERY_HEAVY,
        acclimatized=False,
    )

    assert low.riskLevel == RiskLevel.LOW
    assert (low.workRest.workMinutes, low.workRest.restMinutes) == (60, 0)
    assert (moderate.workRest.workMinutes, moderate.workRest.restMinutes) == (45, 15)
    assert very_high.riskLevel == RiskLevel.VERY_HIGH
    assert very_high.workRest.workMinutes == 0
    assert very_high.workRest.restMinutes == 60


def test_heavier_workload_lowers_wbgt_tolerance() -> None:
    moderate_load = assess_site_risk(
        WorkSafetyEnvironmentInput(lat=1.0, lon=1.0, wbgt_c=26.5),
        WorkloadCategory.MODERATE,
    )
    heavy_load = assess_site_risk(
        WorkSafetyEnvironmentInput(lat=1.0, lon=1.0, wbgt_c=26.5),
        WorkloadCategory.HEAVY,
    )

    assert moderate_load.riskLevel == RiskLevel.MODERATE
    assert heavy_load.riskLevel == RiskLevel.HIGH


def test_estimated_wbgt_is_labeled() -> None:
    env = WorkSafetyEnvironmentInput(
        lat=25.2,
        lon=55.27,
        wbgt_c=28.0,
        wbgt_estimated=True,
        heat_index_c=36.0,
    )
    result = assess_site_risk(env, WorkloadCategory.MODERATE, acclimatized=True)
    assert result.wbgtC == 28.0
    assert "wbgt_assessment" in result.reasonCodes
    assert "wbgt_estimated_from_meteo" in result.reasonCodes
    assert "not_instrument_wbgt" in result.reasonCodes
