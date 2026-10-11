"""HiAir 2.0 Work / B2B occupational heat safety engine (heuristic v0).

Uses occupational WBGT only when explicitly provided. When WBGT is unavailable,
falls back to consumer heat index as a *proxy-only* caution signal — never labeled
as occupational WBGT or NIOSH-compliant guidance.

Work/rest tables are simplified NIOSH-inspired heuristics for scaffolding only;
not medical advice or regulatory compliance certification.
"""

from __future__ import annotations

from app.models.air import RiskLevel
from app.models.work_safety import (
    SiteRiskAssessment,
    WorkloadCategory,
    WorkRestRecommendation,
    WorkSafetyEnvironmentInput,
)

# NIOSH-inspired WBGT caution thresholds (°C) by workload, acclimatized baseline.
_WBGT_THRESHOLDS_ACCLIM: dict[WorkloadCategory, tuple[float, float, float]] = {
    WorkloadCategory.LIGHT: (28.0, 30.0, 32.0),
    WorkloadCategory.MODERATE: (26.0, 28.0, 30.0),
    WorkloadCategory.HEAVY: (24.0, 26.0, 28.0),
    WorkloadCategory.VERY_HEAVY: (22.0, 24.0, 26.0),
}

# Heat-index proxy bands when WBGT is unavailable (°C apparent / feels-like).
_HEAT_INDEX_PROXY_THRESHOLDS: dict[WorkloadCategory, tuple[float, float, float]] = {
    WorkloadCategory.LIGHT: (32.0, 35.0, 38.0),
    WorkloadCategory.MODERATE: (29.0, 32.0, 35.0),
    WorkloadCategory.HEAVY: (27.0, 30.0, 33.0),
    WorkloadCategory.VERY_HEAVY: (25.0, 28.0, 31.0),
}

# Work/rest minutes by risk band and workload (heuristic v0).
_WORK_REST_TABLE: dict[tuple[RiskLevel, WorkloadCategory], tuple[int, int, list[str]]] = {
    (RiskLevel.LOW, WorkloadCategory.LIGHT): (60, 0, ["niosh_heuristic_v0"]),
    (RiskLevel.LOW, WorkloadCategory.MODERATE): (60, 0, ["niosh_heuristic_v0"]),
    (RiskLevel.LOW, WorkloadCategory.HEAVY): (50, 10, ["niosh_heuristic_v0"]),
    (RiskLevel.LOW, WorkloadCategory.VERY_HEAVY): (45, 15, ["niosh_heuristic_v0"]),
    (RiskLevel.MODERATE, WorkloadCategory.LIGHT): (45, 15, ["niosh_heuristic_v0", "elevated_heat_stress"]),
    (RiskLevel.MODERATE, WorkloadCategory.MODERATE): (45, 15, ["niosh_heuristic_v0", "elevated_heat_stress"]),
    (RiskLevel.MODERATE, WorkloadCategory.HEAVY): (30, 30, ["niosh_heuristic_v0", "elevated_heat_stress"]),
    (RiskLevel.MODERATE, WorkloadCategory.VERY_HEAVY): (30, 30, ["niosh_heuristic_v0", "elevated_heat_stress"]),
    (RiskLevel.HIGH, WorkloadCategory.LIGHT): (30, 30, ["niosh_heuristic_v0", "high_heat_stress"]),
    (RiskLevel.HIGH, WorkloadCategory.MODERATE): (30, 30, ["niosh_heuristic_v0", "high_heat_stress"]),
    (RiskLevel.HIGH, WorkloadCategory.HEAVY): (20, 40, ["niosh_heuristic_v0", "high_heat_stress"]),
    (RiskLevel.HIGH, WorkloadCategory.VERY_HEAVY): (15, 45, ["niosh_heuristic_v0", "high_heat_stress"]),
    (RiskLevel.VERY_HIGH, WorkloadCategory.LIGHT): (15, 45, ["niosh_heuristic_v0", "very_high_heat_stress"]),
    (RiskLevel.VERY_HIGH, WorkloadCategory.MODERATE): (15, 45, ["niosh_heuristic_v0", "very_high_heat_stress"]),
    (RiskLevel.VERY_HIGH, WorkloadCategory.HEAVY): (10, 50, ["niosh_heuristic_v0", "very_high_heat_stress"]),
    (RiskLevel.VERY_HIGH, WorkloadCategory.VERY_HEAVY): (0, 60, ["niosh_heuristic_v0", "stop_work_recommended"]),
}


def _site_id(lat: float, lon: float) -> str:
    return f"{lat:.4f}:{lon:.4f}"


def _acclimatization_adjustment(acclimatized: bool) -> float:
    return 0.0 if acclimatized else -2.0


def _risk_from_thresholds(value: float, thresholds: tuple[float, float, float]) -> RiskLevel:
    moderate_at, high_at, very_high_at = thresholds
    if value >= very_high_at:
        return RiskLevel.VERY_HIGH
    if value >= high_at:
        return RiskLevel.HIGH
    if value >= moderate_at:
        return RiskLevel.MODERATE
    return RiskLevel.LOW


def _wbgt_thresholds(workload: WorkloadCategory, acclimatized: bool) -> tuple[float, float, float]:
    base = _WBGT_THRESHOLDS_ACCLIM[workload]
    shift = _acclimatization_adjustment(acclimatized)
    return (base[0] + shift, base[1] + shift, base[2] + shift)


def _heat_index_proxy_thresholds(workload: WorkloadCategory, acclimatized: bool) -> tuple[float, float, float]:
    base = _HEAT_INDEX_PROXY_THRESHOLDS[workload]
    shift = _acclimatization_adjustment(acclimatized)
    return (base[0] + shift, base[1] + shift, base[2] + shift)


def _work_rest(
    risk_level: RiskLevel,
    workload: WorkloadCategory,
    *,
    proxy_only: bool,
) -> WorkRestRecommendation:
    work_minutes, rest_minutes, rationale = _WORK_REST_TABLE[(risk_level, workload)]
    codes = list(rationale)
    if proxy_only:
        codes.append("heat_index_proxy_only")
    return WorkRestRecommendation(
        workMinutes=work_minutes,
        restMinutes=rest_minutes,
        rationaleCodes=codes,
    )


def _metric_availability(env: WorkSafetyEnvironmentInput) -> tuple[list[str], list[str]]:
    available: list[str] = []
    missing: list[str] = []
    if env.wbgt_c is not None:
        available.append("wbgt")
    else:
        missing.append("wbgt")
    if env.heat_index_c is not None:
        available.append("heat_index")
    else:
        missing.append("heat_index")
    return available, missing


def assess_site_risk(
    env: WorkSafetyEnvironmentInput,
    workload: WorkloadCategory,
    *,
    acclimatized: bool = True,
) -> SiteRiskAssessment:
    """Assess occupational site heat risk from explicit metrics only."""
    available_metrics, missing_metrics = _metric_availability(env)
    reason_codes: list[str] = []

    if env.wbgt_c is not None:
        thresholds = _wbgt_thresholds(workload, acclimatized)
        risk_level = _risk_from_thresholds(env.wbgt_c, thresholds)
        reason_codes.append("wbgt_assessment")
        if env.wbgt_estimated:
            reason_codes.extend(["wbgt_estimated_from_meteo", "not_instrument_wbgt"])
        if not acclimatized:
            reason_codes.append("unacclimatized_worker")
        work_rest = _work_rest(risk_level, workload, proxy_only=False)
        return SiteRiskAssessment(
            siteId=_site_id(env.lat, env.lon),
            wbgtC=env.wbgt_c,
            heatIndexC=env.heat_index_c,
            workload=workload,
            riskLevel=risk_level,
            workRest=work_rest,
            availableMetrics=available_metrics,
            missingMetrics=missing_metrics,
            reasonCodes=reason_codes,
        )

    reason_codes.append("wbgt_unavailable")

    if env.heat_index_c is None:
        reason_codes.append("heat_index_unavailable")
        work_rest = WorkRestRecommendation(
            workMinutes=0,
            restMinutes=0,
            rationaleCodes=["insufficient_heat_metrics"],
        )
        return SiteRiskAssessment(
            siteId=_site_id(env.lat, env.lon),
            wbgtC=None,
            heatIndexC=None,
            workload=workload,
            riskLevel=RiskLevel.MODERATE,
            workRest=work_rest,
            availableMetrics=available_metrics,
            missingMetrics=missing_metrics,
            reasonCodes=reason_codes,
        )

    reason_codes.append("heat_index_proxy_only")
    if not acclimatized:
        reason_codes.append("unacclimatized_worker")

    thresholds = _heat_index_proxy_thresholds(workload, acclimatized)
    risk_level = _risk_from_thresholds(env.heat_index_c, thresholds)
    work_rest = _work_rest(risk_level, workload, proxy_only=True)

    return SiteRiskAssessment(
        siteId=_site_id(env.lat, env.lon),
        wbgtC=None,
        heatIndexC=env.heat_index_c,
        workload=workload,
        riskLevel=risk_level,
        workRest=work_rest,
        availableMetrics=available_metrics,
        missingMetrics=missing_metrics,
        reasonCodes=reason_codes,
    )
