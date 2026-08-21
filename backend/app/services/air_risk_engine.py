from datetime import datetime, timedelta

from app.models.air import (
    DayPlanResponse,
    EnvironmentalInput,
    HourlyRiskPoint,
    PersonalLoadAssessment,
    ProfileType,
    RiskAssessmentResult,
    RiskLevel,
    SafeWindow,
    SafeWindowType,
    UserProfileContext,
)
import app.services.personal_load_engine as personal_load_engine
from app.services.personal_load_engine import PersonalLoadInput


RISK_ORDER = {
    RiskLevel.LOW: 0,
    RiskLevel.MODERATE: 1,
    RiskLevel.HIGH: 2,
    RiskLevel.VERY_HIGH: 3,
}


def hour_end_iso(start_iso: str) -> str:
    """Exclusive end of an hourly slot (start 08:00 → end 09:00)."""
    parsed = datetime.fromisoformat(start_iso.replace("Z", "+00:00"))
    return (parsed + timedelta(hours=1)).isoformat()


def _heat_risk(environment: EnvironmentalInput, profile: UserProfileContext) -> tuple[RiskLevel, list[str]]:
    reasons: list[str] = []
    score = 0
    if environment.feels_like >= 40:
        score += 3
        reasons.append("extreme_heat_index")
    elif environment.feels_like >= 34:
        score += 2
        reasons.append("high_heat")
    elif environment.feels_like >= 29:
        score += 1
        reasons.append("moderate_heat")

    if environment.humidity is not None and environment.humidity >= 75:
        score += 1
        reasons.append("high_humidity")
    if environment.uv is not None and environment.uv >= 8:
        score += 1
        reasons.append("uv_peak")

    score += max(0, profile.heat_sensitivity_level - 2)
    if profile.profile_type in (ProfileType.CHILD, ProfileType.ELDERLY, ProfileType.OUTDOOR_WORKER):
        score += 1

    if score >= 5:
        return RiskLevel.VERY_HIGH, reasons
    if score >= 3:
        return RiskLevel.HIGH, reasons
    if score >= 2:
        return RiskLevel.MODERATE, reasons
    return RiskLevel.LOW, reasons


def _air_risk(environment: EnvironmentalInput, profile: UserProfileContext) -> tuple[RiskLevel, list[str]]:
    reasons: list[str] = []
    score = 0
    if environment.aqi is not None:
        if environment.aqi >= 170:
            score += 3
            reasons.append("very_poor_air_quality")
        elif environment.aqi >= 110:
            score += 2
            reasons.append("poor_air_quality")
        elif environment.aqi >= 70:
            score += 1
            reasons.append("elevated_air_quality")

    if environment.pm25 is not None:
        if environment.pm25 >= 45:
            score += 2
            reasons.append("pm25_high")
        elif environment.pm25 >= 20:
            score += 1
            reasons.append("pm25_elevated")

    if environment.pm10 is not None and environment.pm10 >= 60:
        score += 1
        reasons.append("pm10_elevated")
    if environment.ozone is not None and environment.ozone >= 100:
        score += 1
        reasons.append("ozone_elevated")

    if (
        environment.aqi is None
        and environment.pm25 is None
        and environment.pm10 is None
        and environment.ozone is None
    ):
        return RiskLevel.MODERATE, ["air_data_unavailable"]

    score += max(0, profile.respiratory_sensitivity_level - 2)
    if profile.profile_type in (ProfileType.ASTHMA_SENSITIVE, ProfileType.ALLERGY_SENSITIVE):
        score += 2

    if score >= 6:
        return RiskLevel.VERY_HIGH, reasons
    if score >= 4:
        return RiskLevel.HIGH, reasons
    if score >= 2:
        return RiskLevel.MODERATE, reasons
    return RiskLevel.LOW, reasons


def _max_risk(left: RiskLevel, right: RiskLevel) -> RiskLevel:
    return left if RISK_ORDER[left] >= RISK_ORDER[right] else right


def _risk_from_order(value: int) -> RiskLevel:
    if value <= 0:
        return RiskLevel.LOW
    if value == 1:
        return RiskLevel.MODERATE
    if value == 2:
        return RiskLevel.HIGH
    return RiskLevel.VERY_HIGH


def _air_known(environment: EnvironmentalInput) -> bool:
    return environment.aqi is not None or environment.pm25 is not None


def _slot_allowed(
    profile: UserProfileContext,
    environment: EnvironmentalInput,
) -> dict[SafeWindowType, bool]:
    heat_risk, _ = _heat_risk(environment, profile)
    air_risk, air_reasons = _air_risk(environment, profile)
    outdoor_risk = _max_risk(heat_risk, air_risk)
    air_ok = _air_known(environment) and "air_data_unavailable" not in air_reasons
    ventilation_ok = (
        environment.aqi is not None
        and environment.pm25 is not None
        and environment.ozone is not None
        and environment.aqi <= 75
        and environment.pm25 <= 18
        and environment.ozone <= 80
    )
    return {
        SafeWindowType.WALK: air_ok and RISK_ORDER[outdoor_risk] <= 1,
        SafeWindowType.RUN: air_ok and RISK_ORDER[outdoor_risk] == 0 and environment.feels_like < 30,
        SafeWindowType.VENTILATION: ventilation_ok,
        SafeWindowType.GENERAL_OUTDOOR: air_ok and RISK_ORDER[outdoor_risk] <= 1,
    }


def _window_confidence(environment: EnvironmentalInput, window_type: SafeWindowType) -> float:
    missing = sum(
        1
        for attr in ("uv", "pm10", "wind_speed", "aqi", "pm25", "ozone")
        if getattr(environment, attr) is None
    )
    base = 0.72 if window_type == SafeWindowType.RUN else 0.86
    return max(0.4, round(base - missing * 0.04, 2))


def _build_safe_windows_from_hourly(
    profile: UserProfileContext,
    hourly: list[EnvironmentalInput],
) -> list[SafeWindow]:
    """Merge consecutive hourly forecast points. Hour grid only — no minute precision."""
    windows: list[SafeWindow] = []
    open_windows: dict[SafeWindowType, str | None] = {
        SafeWindowType.WALK: None,
        SafeWindowType.RUN: None,
        SafeWindowType.VENTILATION: None,
        SafeWindowType.GENERAL_OUTDOOR: None,
    }
    last_seen: dict[SafeWindowType, str | None] = {
        SafeWindowType.WALK: None,
        SafeWindowType.RUN: None,
        SafeWindowType.VENTILATION: None,
        SafeWindowType.GENERAL_OUTDOOR: None,
    }
    last_env: dict[SafeWindowType, EnvironmentalInput | None] = {
        SafeWindowType.WALK: None,
        SafeWindowType.RUN: None,
        SafeWindowType.VENTILATION: None,
        SafeWindowType.GENERAL_OUTDOOR: None,
    }

    for slot in hourly:
        status_by_type = _slot_allowed(profile, slot)
        for window_type, is_open in status_by_type.items():
            if is_open and open_windows[window_type] is None:
                open_windows[window_type] = slot.timestamp
            if is_open:
                last_seen[window_type] = slot.timestamp
                last_env[window_type] = slot
            if not is_open and open_windows[window_type] is not None and last_seen[window_type] is not None:
                env = last_env[window_type] or slot
                windows.append(
                    SafeWindow(
                        type=window_type,
                        start=open_windows[window_type],
                        end=hour_end_iso(last_seen[window_type]),
                        confidence=_window_confidence(env, window_type),
                    )
                )
                open_windows[window_type] = None
                last_seen[window_type] = None
                last_env[window_type] = None

    for window_type, start_time in open_windows.items():
        if start_time is not None and last_seen[window_type] is not None:
            env = last_env[window_type] or hourly[-1]
            windows.append(
                SafeWindow(
                    type=window_type,
                    start=start_time,
                    end=hour_end_iso(last_seen[window_type]),
                    confidence=_window_confidence(env, window_type),
                )
            )
    return windows


def _build_recommendation_flags(
    overall: RiskLevel,
    heat_risk: RiskLevel,
    air_risk: RiskLevel,
    profile: UserProfileContext,
) -> list[str]:
    flags: list[str] = []
    if RISK_ORDER[overall] >= 2:
        flags.append("avoid_outdoor_now")
    if RISK_ORDER[heat_risk] >= 2:
        flags.append("reduce_exertion")
    if RISK_ORDER[air_risk] >= 2:
        flags.append("keep_windows_closed")
        flags.append("ventilate_later")
    if profile.profile_type == ProfileType.CHILD:
        flags.append("child_caution")
    if profile.profile_type == ProfileType.ASTHMA_SENSITIVE:
        flags.append("asthma_caution")
    if profile.profile_type == ProfileType.RUNNER and RISK_ORDER[overall] >= 1:
        flags.append("avoid_running")
    return sorted(set(flags))


def evaluate_risk(
    profile: UserProfileContext,
    environment: EnvironmentalInput,
    personal_load: PersonalLoadInput | None = None,
    hourly_points: list[EnvironmentalInput] | None = None,
) -> RiskAssessmentResult:
    heat_risk, heat_reasons = _heat_risk(environment, profile)
    air_risk, air_reasons = _air_risk(environment, profile)
    outdoor_risk = _max_risk(heat_risk, air_risk)

    ventilation_order = RISK_ORDER[air_risk]
    if environment.wind_speed is not None and environment.wind_speed < 1.5:
        ventilation_order = min(3, ventilation_order + 1)
    indoor_ventilation_risk = _risk_from_order(ventilation_order)

    overall_order = max(RISK_ORDER[heat_risk], RISK_ORDER[air_risk])
    if RISK_ORDER[heat_risk] >= 2 and RISK_ORDER[air_risk] >= 2:
        overall_order = min(3, overall_order + 1)

    # Personal load is the current/latest validated context for every hour.
    # Do not invent future physiology for forecast points.
    personal_load_result = personal_load_engine.compute_personal_load_score(
        personal_load
        if personal_load is not None
        else PersonalLoadInput(
            heat_index=environment.feels_like,
            temperature=environment.temperature,
            humidity=environment.humidity,
            aqi=environment.aqi,
            ozone=environment.ozone,
            pm25=environment.pm25,
            consent_active=False,
        )
    )
    load_bump = personal_load_engine.personal_load_risk_bump(personal_load_result.score)
    if load_bump > 0:
        overall_order = min(3, overall_order + load_bump)

    overall_risk = _risk_from_order(overall_order)

    all_windows = _build_safe_windows_from_hourly(profile, hourly_points or [])
    outdoor_windows = [
        window
        for window in all_windows
        if window.type
        in (SafeWindowType.WALK, SafeWindowType.RUN, SafeWindowType.GENERAL_OUTDOOR)
    ]
    ventilation_windows = [
        window for window in all_windows if window.type == SafeWindowType.VENTILATION
    ]
    reason_codes = sorted(set(heat_reasons + air_reasons + personal_load_result.reason_codes))
    if ventilation_windows:
        reason_codes.append("night_ventilation_better")

    recommendation_flags = _build_recommendation_flags(overall_risk, heat_risk, air_risk, profile)
    if personal_load_result.score >= 25:
        recommendation_flags.append("reduce_exertion")
        recommendation_flags = sorted(set(recommendation_flags))

    personal_load_assessment = PersonalLoadAssessment(
        score=personal_load_result.score,
        level=personal_load_result.level,
        explanations=personal_load_result.explanations,
        reasonCodes=personal_load_result.reason_codes,
    )

    return RiskAssessmentResult(
        overallRisk=overall_risk,
        heatRisk=heat_risk,
        airRisk=air_risk,
        outdoorRisk=outdoor_risk,
        indoorVentilationRisk=indoor_ventilation_risk,
        safeWindows=outdoor_windows,
        recommendationFlags=recommendation_flags,
        reasonCodes=sorted(set(reason_codes)),
        personalLoad=personal_load_assessment,
        ventilationWindows=ventilation_windows,
    )


def build_day_plan(
    profile: UserProfileContext,
    environment: EnvironmentalInput,
    hourly_points: list[EnvironmentalInput] | None = None,
    *,
    personal_load: PersonalLoadInput | None = None,
    generated_at: str | None = None,
    freshness: str | None = None,
    data_quality: str | None = None,
    sources: list[str] | None = None,
    missing_metrics: list[str] | None = None,
) -> DayPlanResponse:
    points = hourly_points or []
    hourly: list[HourlyRiskPoint] = []
    for slot in points:
        # Reuse current personal-load context; do not extrapolate future physiology.
        risk = evaluate_risk(profile, slot, personal_load, hourly_points=[])
        hourly.append(HourlyRiskPoint(hour=slot.timestamp, overallRisk=risk.overallRisk))

    all_windows = _build_safe_windows_from_hourly(profile, points)
    ventilation_windows = [window for window in all_windows if window.type == SafeWindowType.VENTILATION]
    outdoor_windows = [
        window
        for window in all_windows
        if window.type
        in (SafeWindowType.WALK, SafeWindowType.RUN, SafeWindowType.GENERAL_OUTDOOR)
    ]
    available = len(points) > 0
    return DayPlanResponse(
        profileId=profile.profile_id,
        timezone=points[0].timezone if points else environment.timezone,
        hourlyRisk=hourly,
        safeWindows=outdoor_windows,
        ventilationWindows=ventilation_windows,
        generatedAt=generated_at,
        dataQuality=data_quality if data_quality is not None else ("unavailable" if not available else "complete"),
        freshness=freshness,
        sources=sources,
        forecastHours=len(points) if available else 0,
        forecastAvailable=available,
        missingMetrics=missing_metrics or [],
    )
