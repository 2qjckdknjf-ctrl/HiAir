"""HiAir 1.3 multi-hazard scoring from real environmental inputs only."""

from app.models.air import EnvironmentalInput, ProfileType, UserProfileContext
from app.models.hazard import (
    HAZARD_LEVEL_ORDER,
    HazardLevel,
    HazardScore,
    HazardType,
    MultiHazardAssessment,
)
from app.services.air_score import RISK_LEVEL_TO_SCORE


def _level_from_score(score: int) -> HazardLevel:
    if score >= 80:
        return HazardLevel.VERY_HIGH
    if score >= 60:
        return HazardLevel.HIGH
    if score >= 35:
        return HazardLevel.MODERATE
    return HazardLevel.LOW


def _max_level(left: HazardLevel, right: HazardLevel) -> HazardLevel:
    if HAZARD_LEVEL_ORDER[left] >= HAZARD_LEVEL_ORDER[right]:
        return left
    return right


def _unavailable(hazard: HazardType, reason: str = "provider_not_configured") -> HazardScore:
    return HazardScore(
        hazard=hazard,
        level=HazardLevel.UNAVAILABLE,
        score=0,
        available=False,
        reasonCodes=[reason],
        unavailableReason=reason,
    )


def score_heat(environment: EnvironmentalInput, profile: UserProfileContext) -> HazardScore:
    reasons: list[str] = []
    points = 0

    if environment.feels_like >= 40:
        points += 3
        reasons.append("extreme_heat_index")
    elif environment.feels_like >= 34:
        points += 2
        reasons.append("high_heat")
    elif environment.feels_like >= 29:
        points += 1
        reasons.append("moderate_heat")

    if environment.humidity is not None and environment.humidity >= 75:
        points += 1
        reasons.append("high_humidity")

    points += max(0, profile.heat_sensitivity_level - 2)
    if profile.profile_type in (ProfileType.CHILD, ProfileType.ELDERLY, ProfileType.OUTDOOR_WORKER):
        points += 1
        reasons.append("profile_heat_sensitivity")

    if points >= 5:
        level = HazardLevel.VERY_HIGH
    elif points >= 3:
        level = HazardLevel.HIGH
    elif points >= 2:
        level = HazardLevel.MODERATE
    else:
        level = HazardLevel.LOW

    return HazardScore(
        hazard=HazardType.HEAT,
        level=level,
        score=RISK_LEVEL_TO_SCORE[level.value],
        available=True,
        reasonCodes=reasons,
    )


def _air_metrics_present(environment: EnvironmentalInput) -> bool:
    return (
        environment.aqi is not None
        or environment.pm25 is not None
        or environment.pm10 is not None
        or environment.ozone is not None
    )


def score_air(environment: EnvironmentalInput, profile: UserProfileContext) -> HazardScore:
    if not _air_metrics_present(environment):
        return _unavailable(HazardType.AIR, "air_metrics_unavailable")

    reasons: list[str] = []
    points = 0

    if environment.aqi is not None:
        if environment.aqi >= 170:
            points += 3
            reasons.append("very_poor_air_quality")
        elif environment.aqi >= 110:
            points += 2
            reasons.append("poor_air_quality")
        elif environment.aqi >= 70:
            points += 1
            reasons.append("elevated_air_quality")

    if environment.pm25 is not None:
        if environment.pm25 >= 45:
            points += 2
            reasons.append("pm25_high")
        elif environment.pm25 >= 20:
            points += 1
            reasons.append("pm25_elevated")

    if environment.pm10 is not None and environment.pm10 >= 60:
        points += 1
        reasons.append("pm10_elevated")
    if environment.ozone is not None and environment.ozone >= 100:
        points += 1
        reasons.append("ozone_elevated")

    points += max(0, profile.respiratory_sensitivity_level - 2)
    if profile.profile_type in (ProfileType.ASTHMA_SENSITIVE, ProfileType.ALLERGY_SENSITIVE):
        points += 2
        reasons.append("profile_respiratory_sensitivity")

    if points >= 6:
        level = HazardLevel.VERY_HIGH
    elif points >= 4:
        level = HazardLevel.HIGH
    elif points >= 2:
        level = HazardLevel.MODERATE
    else:
        level = HazardLevel.LOW

    return HazardScore(
        hazard=HazardType.AIR,
        level=level,
        score=RISK_LEVEL_TO_SCORE[level.value],
        available=True,
        reasonCodes=reasons,
    )


def score_uv(environment: EnvironmentalInput, profile: UserProfileContext) -> HazardScore:
    if environment.uv is None:
        return _unavailable(HazardType.UV, "uv_unavailable")

    reasons: list[str] = []
    uv = environment.uv
    if uv >= 11:
        base_score = 95
        reasons.append("uv_extreme")
    elif uv >= 8:
        base_score = 90
        reasons.append("uv_very_high")
    elif uv >= 6:
        base_score = 70
        reasons.append("uv_high")
    elif uv >= 3:
        base_score = 45
        reasons.append("uv_moderate")
    else:
        base_score = 20
        reasons.append("uv_low")

    sensitivity_boost = max(0, profile.heat_sensitivity_level - 2) * 5
    score = min(100, base_score + sensitivity_boost)
    level = _level_from_score(score)

    return HazardScore(
        hazard=HazardType.UV,
        level=level,
        score=score,
        available=True,
        reasonCodes=reasons,
    )


def score_pollen(_environment: EnvironmentalInput, _profile: UserProfileContext) -> HazardScore:
    return _unavailable(HazardType.POLLEN)


def score_smoke(_environment: EnvironmentalInput, _profile: UserProfileContext) -> HazardScore:
    return _unavailable(HazardType.SMOKE)


def score_dust(environment: EnvironmentalInput, profile: UserProfileContext) -> HazardScore:
    if environment.pm10 is None:
        return _unavailable(HazardType.DUST, "pm10_unavailable")

    reasons: list[str] = ["pm10_coarse_particulate"]
    pm10 = environment.pm10
    if pm10 >= 100:
        level = HazardLevel.VERY_HIGH
        reasons.append("pm10_very_high")
    elif pm10 >= 70:
        level = HazardLevel.HIGH
        reasons.append("pm10_high")
    elif pm10 >= 40:
        level = HazardLevel.MODERATE
        reasons.append("pm10_elevated")
    else:
        level = HazardLevel.LOW
        reasons.append("pm10_low")

    if profile.profile_type in (ProfileType.ASTHMA_SENSITIVE, ProfileType.ALLERGY_SENSITIVE):
        reasons.append("profile_respiratory_sensitivity")
        if HAZARD_LEVEL_ORDER[level] < HAZARD_LEVEL_ORDER[HazardLevel.MODERATE]:
            level = HazardLevel.MODERATE

    return HazardScore(
        hazard=HazardType.DUST,
        level=level,
        score=RISK_LEVEL_TO_SCORE[level.value],
        available=True,
        reasonCodes=reasons,
    )


def assess_multi_hazard(
    profile: UserProfileContext,
    environment: EnvironmentalInput,
) -> MultiHazardAssessment:
    hazards = [
        score_heat(environment, profile),
        score_air(environment, profile),
        score_uv(environment, profile),
        score_pollen(environment, profile),
        score_smoke(environment, profile),
        score_dust(environment, profile),
    ]

    available = [item for item in hazards if item.available]
    if available:
        overall_level = HazardLevel.LOW
        overall_score = 0
        for item in available:
            overall_level = _max_level(overall_level, item.level)
            overall_score = max(overall_score, item.score)
    else:
        overall_level = HazardLevel.UNAVAILABLE
        overall_score = 0

    reason_codes: list[str] = []
    for item in hazards:
        reason_codes.extend(item.reasonCodes)

    return MultiHazardAssessment(
        profileId=profile.profile_id,
        assessedAt=environment.timestamp,
        hazards=hazards,
        overallLevel=overall_level,
        overallScore=overall_score,
        availableCount=len(available),
        reasonCodes=sorted(set(reason_codes)),
    )
