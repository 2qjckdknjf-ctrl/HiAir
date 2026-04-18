from datetime import datetime, timedelta, timezone
import math

from app.models.air import (
    DayPlanResponse,
    EnvironmentalInput,
    HourlyRiskPoint,
    ProfileType,
    RiskAssessmentResult,
    RiskLevel,
    SafeWindow,
    SafeWindowType,
    UserProfileContext,
)


RISK_ORDER = {
    RiskLevel.LOW: 0,
    RiskLevel.MODERATE: 1,
    RiskLevel.HIGH: 2,
    RiskLevel.VERY_HIGH: 3,
}


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

    if environment.humidity >= 75:
        score += 1
        reasons.append("high_humidity")
    if environment.uv >= 8:
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
    if environment.aqi >= 170:
        score += 3
        reasons.append("very_poor_air_quality")
    elif environment.aqi >= 110:
        score += 2
        reasons.append("poor_air_quality")
    elif environment.aqi >= 70:
        score += 1
        reasons.append("elevated_air_quality")

    if environment.pm25 >= 45:
        score += 2
        reasons.append("pm25_high")
    elif environment.pm25 >= 20:
        score += 1
        reasons.append("pm25_elevated")

    if environment.pm10 >= 60:
        score += 1
        reasons.append("pm10_elevated")
    if environment.ozone >= 100:
        score += 1
        reasons.append("ozone_elevated")

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


def _project_environment(environment: EnvironmentalInput, hour_offset: int) -> EnvironmentalInput:
    hour_in_day = (datetime.now(timezone.utc).hour + hour_offset) % 24
    heat_wave = max(0.0, math.sin((hour_in_day - 7) / 24 * math.pi * 2))
    traffic_wave = max(0.0, math.sin((hour_in_day - 5) / 24 * math.pi * 2))

    projected_temp = environment.temperature + (heat_wave * 6.0) - 2.0
    projected_feels_like = environment.feels_like + (heat_wave * 7.0) - 2.5
    projected_humidity = min(100.0, max(20.0, environment.humidity - (heat_wave * 8.0) + 3.0))
    projected_aqi = int(max(5.0, environment.aqi + (traffic_wave * 30.0) - 12.0))
    projected_pm25 = max(1.0, environment.pm25 + (traffic_wave * 12.0) - 5.0)
    projected_pm10 = max(1.0, environment.pm10 + (traffic_wave * 15.0) - 6.0)
    projected_ozone = max(1.0, environment.ozone + (heat_wave * 18.0) - 7.0)
    projected_uv = max(0.0, environment.uv + (heat_wave * 3.0) - 1.5)
    projected_wind = max(0.0, environment.wind_speed + (math.cos(hour_offset / 3) * 1.2))

    return EnvironmentalInput(
        lat=environment.lat,
        lon=environment.lon,
        temperature=round(projected_temp, 1),
        feels_like=round(projected_feels_like, 1),
        humidity=round(projected_humidity, 1),
        aqi=projected_aqi,
        pm25=round(projected_pm25, 1),
        pm10=round(projected_pm10, 1),
        ozone=round(projected_ozone, 1),
        uv=round(projected_uv, 1),
        wind_speed=round(projected_wind, 1),
        source=environment.source,
        timestamp=(datetime.now(timezone.utc) + timedelta(hours=hour_offset)).isoformat(),
        timezone=environment.timezone,
    )


def _build_safe_windows(profile: UserProfileContext, environment: EnvironmentalInput) -> list[SafeWindow]:
    now = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0)
    windows: list[SafeWindow] = []
    open_windows: dict[SafeWindowType, datetime | None] = {
        SafeWindowType.WALK: None,
        SafeWindowType.RUN: None,
        SafeWindowType.VENTILATION: None,
        SafeWindowType.GENERAL_OUTDOOR: None,
    }
    last_seen: dict[SafeWindowType, datetime | None] = {
        SafeWindowType.WALK: None,
        SafeWindowType.RUN: None,
        SafeWindowType.VENTILATION: None,
        SafeWindowType.GENERAL_OUTDOOR: None,
    }

    for hour_offset in range(24):
        slot_time = now + timedelta(hours=hour_offset)
        projected = _project_environment(environment, hour_offset)
        heat_risk, _ = _heat_risk(projected, profile)
        air_risk, _ = _air_risk(projected, profile)
        outdoor_risk = _max_risk(heat_risk, air_risk)

        status_by_type = {
            SafeWindowType.WALK: RISK_ORDER[outdoor_risk] <= 1,
            SafeWindowType.RUN: RISK_ORDER[outdoor_risk] == 0 and projected.feels_like < 30,
            SafeWindowType.VENTILATION: projected.aqi <= 75 and projected.pm25 <= 18 and projected.ozone <= 80,
            SafeWindowType.GENERAL_OUTDOOR: RISK_ORDER[outdoor_risk] <= 1,
        }

        for window_type, is_open in status_by_type.items():
            if is_open and open_windows[window_type] is None:
                open_windows[window_type] = slot_time
            if is_open:
                last_seen[window_type] = slot_time
            if not is_open and open_windows[window_type] is not None and last_seen[window_type] is not None:
                confidence = 0.86 if window_type != SafeWindowType.RUN else 0.72
                windows.append(
                    SafeWindow(
                        type=window_type,
                        start=open_windows[window_type].isoformat(),
                        end=last_seen[window_type].isoformat(),
                        confidence=confidence,
                    )
                )
                open_windows[window_type] = None
                last_seen[window_type] = None

    for window_type, start_time in open_windows.items():
        if start_time is not None and last_seen[window_type] is not None:
            confidence = 0.86 if window_type != SafeWindowType.RUN else 0.72
            windows.append(
                SafeWindow(
                    type=window_type,
                    start=start_time.isoformat(),
                    end=last_seen[window_type].isoformat(),
                    confidence=confidence,
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


def evaluate_risk(profile: UserProfileContext, environment: EnvironmentalInput) -> RiskAssessmentResult:
    heat_risk, heat_reasons = _heat_risk(environment, profile)
    air_risk, air_reasons = _air_risk(environment, profile)
    outdoor_risk = _max_risk(heat_risk, air_risk)

    ventilation_order = RISK_ORDER[air_risk]
    if environment.wind_speed < 1.5:
        ventilation_order = min(3, ventilation_order + 1)
    indoor_ventilation_risk = _risk_from_order(ventilation_order)

    overall_order = max(RISK_ORDER[heat_risk], RISK_ORDER[air_risk])
    if RISK_ORDER[heat_risk] >= 2 and RISK_ORDER[air_risk] >= 2:
        overall_order = min(3, overall_order + 1)
    overall_risk = _risk_from_order(overall_order)

    reason_codes = sorted(set(heat_reasons + air_reasons))
    if any(window.type == SafeWindowType.VENTILATION for window in _build_safe_windows(profile, environment)):
        reason_codes.append("night_ventilation_better")

    return RiskAssessmentResult(
        overallRisk=overall_risk,
        heatRisk=heat_risk,
        airRisk=air_risk,
        outdoorRisk=outdoor_risk,
        indoorVentilationRisk=indoor_ventilation_risk,
        safeWindows=_build_safe_windows(profile, environment),
        recommendationFlags=_build_recommendation_flags(overall_risk, heat_risk, air_risk, profile),
        reasonCodes=sorted(set(reason_codes)),
    )


def build_day_plan(profile: UserProfileContext, environment: EnvironmentalInput) -> DayPlanResponse:
    now = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0)
    hourly: list[HourlyRiskPoint] = []
    for hour_offset in range(24):
        projected = _project_environment(environment, hour_offset)
        risk = evaluate_risk(profile, projected)
        hourly.append(HourlyRiskPoint(hour=(now + timedelta(hours=hour_offset)).isoformat(), overallRisk=risk.overallRisk))

    all_windows = _build_safe_windows(profile, environment)
    ventilation_windows = [window for window in all_windows if window.type == SafeWindowType.VENTILATION]
    return DayPlanResponse(
        profileId=profile.profile_id,
        timezone=profile.timezone,
        hourlyRisk=hourly,
        safeWindows=all_windows,
        ventilationWindows=ventilation_windows,
    )
