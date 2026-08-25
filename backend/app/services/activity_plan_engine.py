"""HiAir 1.2 activity decision engine.

Deterministic Best / Acceptable / Avoid scoring from real hourly forecast points.
AI may explain reason codes later — it must not invent environmental values or scores.
"""

from __future__ import annotations

from datetime import datetime
from math import ceil

from app.models.activity_plan import (
    ActivityCatalogItem,
    ActivityHourAssessment,
    ActivityIntensity,
    ActivityPlanResponse,
    ActivityType,
    ActivityWindow,
    ActivityWindowTier,
)
from app.models.air import EnvironmentalInput, ProfileType, RiskLevel, UserProfileContext
from app.services import air_risk_engine
from app.services.personal_load_engine import PersonalLoadInput, compute_personal_load_score


ACTIVITY_CATALOG: list[ActivityCatalogItem] = [
    ActivityCatalogItem(
        activity=ActivityType.RUNNING,
        defaultDurationMinutes=45,
        defaultIntensity=ActivityIntensity.HIGH,
    ),
    ActivityCatalogItem(
        activity=ActivityType.WALKING,
        defaultDurationMinutes=30,
        defaultIntensity=ActivityIntensity.LOW,
    ),
    ActivityCatalogItem(
        activity=ActivityType.CYCLING,
        defaultDurationMinutes=60,
        defaultIntensity=ActivityIntensity.MODERATE,
    ),
    ActivityCatalogItem(
        activity=ActivityType.HIKING,
        defaultDurationMinutes=90,
        defaultIntensity=ActivityIntensity.MODERATE,
    ),
    ActivityCatalogItem(
        activity=ActivityType.DOG_WALK,
        defaultDurationMinutes=30,
        defaultIntensity=ActivityIntensity.LOW,
    ),
    ActivityCatalogItem(
        activity=ActivityType.PLAYGROUND,
        defaultDurationMinutes=60,
        defaultIntensity=ActivityIntensity.LOW,
    ),
    ActivityCatalogItem(
        activity=ActivityType.OUTDOOR_SPORT,
        defaultDurationMinutes=60,
        defaultIntensity=ActivityIntensity.HIGH,
    ),
    ActivityCatalogItem(
        activity=ActivityType.BEACH,
        defaultDurationMinutes=120,
        defaultIntensity=ActivityIntensity.MODERATE,
    ),
    ActivityCatalogItem(
        activity=ActivityType.OUTDOOR_WORK,
        defaultDurationMinutes=120,
        defaultIntensity=ActivityIntensity.MODERATE,
    ),
    ActivityCatalogItem(
        activity=ActivityType.VENTILATION,
        defaultDurationMinutes=60,
        defaultIntensity=ActivityIntensity.LOW,
        outdoor=False,
    ),
]

_CATALOG_BY_ACTIVITY = {item.activity: item for item in ACTIVITY_CATALOG}

_RISK_ORDER = {
    RiskLevel.LOW: 0,
    RiskLevel.MODERATE: 1,
    RiskLevel.HIGH: 2,
    RiskLevel.VERY_HIGH: 3,
}


def catalog() -> list[ActivityCatalogItem]:
    return list(ACTIVITY_CATALOG)


def resolve_defaults(
    activity: ActivityType,
    duration_minutes: int | None,
    intensity: ActivityIntensity | None,
) -> tuple[int, ActivityIntensity]:
    item = _CATALOG_BY_ACTIVITY[activity]
    return (
        duration_minutes if duration_minutes is not None else item.defaultDurationMinutes,
        intensity if intensity is not None else item.defaultIntensity,
    )


def _parse_iso(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _within_flex(slot_start: str, earliest: str | None, latest: str | None) -> bool:
    start = _parse_iso(slot_start)
    if earliest is not None and start < _parse_iso(earliest):
        return False
    if latest is not None and start > _parse_iso(latest):
        return False
    return True


def _confidence(environment: EnvironmentalInput) -> float:
    missing = sum(
        1
        for attr in ("uv", "pm10", "wind_speed", "aqi", "pm25", "ozone")
        if getattr(environment, attr) is None
    )
    return max(0.4, round(0.9 - missing * 0.05, 2))


def _intensity_heat_cap(intensity: ActivityIntensity) -> tuple[float, float]:
    """Return (best_feels_like_max, acceptable_feels_like_max)."""
    if intensity == ActivityIntensity.HIGH:
        return 28.0, 32.0
    if intensity == ActivityIntensity.MODERATE:
        return 30.0, 34.0
    return 32.0, 36.0


def _score_ventilation(environment: EnvironmentalInput) -> tuple[ActivityWindowTier, int, list[str]]:
    reasons: list[str] = []
    if environment.aqi is None or environment.pm25 is None or environment.ozone is None:
        return ActivityWindowTier.AVOID, 25, ["air_data_unavailable"]
    ok = environment.aqi <= 75 and environment.pm25 <= 18 and environment.ozone <= 80
    if not ok:
        if environment.aqi > 75:
            reasons.append("aqi")
        if environment.pm25 > 18:
            reasons.append("pm25")
        if environment.ozone > 80:
            reasons.append("ozone")
        return ActivityWindowTier.AVOID, 20, reasons or ["air"]
    return ActivityWindowTier.BEST, 90, ["good_air"]


def _score_outdoor_hour(
    *,
    activity: ActivityType,
    intensity: ActivityIntensity,
    profile: UserProfileContext,
    environment: EnvironmentalInput,
    personal_load_score: int,
) -> tuple[ActivityWindowTier, int, list[str]]:
    heat_risk, heat_reasons = air_risk_engine._heat_risk(environment, profile)
    air_risk, air_reasons = air_risk_engine._air_risk(environment, profile)
    outdoor = air_risk_engine._max_risk(heat_risk, air_risk)
    outdoor_order = _RISK_ORDER[outdoor]
    reasons = sorted(set(heat_reasons + air_reasons))

    air_ok = air_risk_engine._air_known(environment) and "air_data_unavailable" not in air_reasons
    if not air_ok:
        reasons.append("air_data_unavailable")
        return ActivityWindowTier.AVOID, 30, sorted(set(reasons))

    best_cap, acceptable_cap = _intensity_heat_cap(intensity)
    feels = environment.feels_like

    if activity == ActivityType.PLAYGROUND or profile.profile_type == ProfileType.CHILD:
        best_cap -= 2.0
        acceptable_cap -= 2.0
        if activity == ActivityType.PLAYGROUND:
            reasons.append("child_caution")
    if activity == ActivityType.OUTDOOR_WORK or profile.profile_type == ProfileType.OUTDOOR_WORKER:
        best_cap -= 1.0
        acceptable_cap -= 1.0

    if activity == ActivityType.BEACH:
        if environment.uv is None:
            reasons.append("uv_unavailable")
        elif environment.uv >= 11:
            reasons.append("uv")
            return ActivityWindowTier.AVOID, 15, sorted(set(reasons))
        elif environment.uv >= 8:
            reasons.append("uv")
            outdoor_order = max(outdoor_order, 1)

    if personal_load_score >= 40 and intensity == ActivityIntensity.HIGH:
        outdoor_order = min(3, outdoor_order + 1)
        reasons.append("personal_load")
    elif personal_load_score >= 55:
        outdoor_order = min(3, outdoor_order + 1)
        reasons.append("personal_load")

    if outdoor_order >= 3 or feels >= acceptable_cap + 2:
        reasons.append("heat" if _RISK_ORDER[heat_risk] >= _RISK_ORDER[air_risk] else "air")
        return ActivityWindowTier.AVOID, max(5, 40 - outdoor_order * 10), sorted(set(reasons))

    if outdoor_order == 0 and feels < best_cap:
        score = 92 - int(max(0.0, feels - (best_cap - 4)))
        reasons.append("low_heat")
        reasons.append("good_air")
        return ActivityWindowTier.BEST, max(75, min(100, score)), sorted(set(reasons))

    if outdoor_order <= 1 and feels < acceptable_cap:
        score = 70 - outdoor_order * 8 - int(max(0.0, feels - best_cap))
        return ActivityWindowTier.ACCEPTABLE, max(45, min(74, score)), sorted(set(reasons))

    reasons.append("heat" if _RISK_ORDER[heat_risk] >= _RISK_ORDER[air_risk] else "air")
    return ActivityWindowTier.AVOID, max(10, 35 - outdoor_order * 8), sorted(set(reasons))


def score_hour(
    *,
    activity: ActivityType,
    intensity: ActivityIntensity,
    profile: UserProfileContext,
    environment: EnvironmentalInput,
    personal_load_score: int = 0,
) -> ActivityHourAssessment:
    if activity == ActivityType.VENTILATION:
        tier, score, reasons = _score_ventilation(environment)
    else:
        tier, score, reasons = _score_outdoor_hour(
            activity=activity,
            intensity=intensity,
            profile=profile,
            environment=environment,
            personal_load_score=personal_load_score,
        )
    return ActivityHourAssessment(
        hour=environment.timestamp,
        tier=tier,
        score=score,
        reasonCodes=reasons,
    )


def _merge_windows(
    hourly: list[ActivityHourAssessment],
    environments: list[EnvironmentalInput],
) -> list[ActivityWindow]:
    if not hourly:
        return []
    env_by_ts = {env.timestamp: env for env in environments}
    windows: list[ActivityWindow] = []
    run_start = hourly[0].hour
    run_tier = hourly[0].tier
    run_scores = [hourly[0].score]
    run_reasons: list[str] = list(hourly[0].reasonCodes)
    last_hour = hourly[0].hour

    def flush() -> None:
        env = env_by_ts.get(last_hour) or environments[-1]
        windows.append(
            ActivityWindow(
                tier=run_tier,
                start=run_start,
                end=air_risk_engine.hour_end_iso(last_hour),
                score=int(sum(run_scores) / len(run_scores)),
                reasonCodes=sorted(set(run_reasons)),
                confidence=_confidence(env),
            )
        )

    for point in hourly[1:]:
        if point.tier == run_tier:
            run_scores.append(point.score)
            run_reasons.extend(point.reasonCodes)
            last_hour = point.hour
            continue
        flush()
        run_start = point.hour
        run_tier = point.tier
        run_scores = [point.score]
        run_reasons = list(point.reasonCodes)
        last_hour = point.hour
    flush()
    return windows


def _pick_recommended_start(
    hourly: list[ActivityHourAssessment],
    duration_minutes: int,
    earliest: str | None,
    latest: str | None,
) -> str | None:
    need_hours = max(1, ceil(duration_minutes / 60))
    for preferred in (ActivityWindowTier.BEST, ActivityWindowTier.ACCEPTABLE):
        for index in range(0, len(hourly) - need_hours + 1):
            chunk = hourly[index : index + need_hours]
            if not all(point.tier == preferred for point in chunk):
                continue
            start = chunk[0].hour
            if not _within_flex(start, earliest, latest):
                continue
            return start
    return None


def build_activity_plan(
    *,
    profile: UserProfileContext,
    environment: EnvironmentalInput,
    hourly_points: list[EnvironmentalInput],
    activity: ActivityType,
    duration_minutes: int | None = None,
    intensity: ActivityIntensity | None = None,
    earliest_start: str | None = None,
    latest_start: str | None = None,
    personal_load: PersonalLoadInput | None = None,
    generated_at: str | None = None,
    freshness: str | None = None,
    data_quality: str | None = None,
    sources: list[str] | None = None,
    missing_metrics: list[str] | None = None,
) -> ActivityPlanResponse:
    resolved_duration, resolved_intensity = resolve_defaults(activity, duration_minutes, intensity)

    load_score = 0
    load_level: str | None = None
    load_reasons: list[str] = []
    if personal_load is not None:
        load_result = compute_personal_load_score(personal_load)
        load_score = load_result.score
        load_level = load_result.level
        load_reasons = list(load_result.reason_codes)

    if earliest_start or latest_start:
        points = [
            slot
            for slot in hourly_points
            if _within_flex(slot.timestamp, earliest_start, latest_start)
        ]
    else:
        points = list(hourly_points)

    hourly = [
        score_hour(
            activity=activity,
            intensity=resolved_intensity,
            profile=profile,
            environment=slot,
            personal_load_score=load_score,
        )
        for slot in points
    ]
    windows = _merge_windows(hourly, points)
    available = len(points) > 0
    recommended = (
        _pick_recommended_start(hourly, resolved_duration, earliest_start, latest_start)
        if available
        else None
    )

    return ActivityPlanResponse(
        profileId=profile.profile_id,
        activity=activity,
        intensity=resolved_intensity,
        durationMinutes=resolved_duration,
        timezone=points[0].timezone if points else environment.timezone,
        forecastAvailable=available,
        dataQuality=(
            data_quality if data_quality is not None else ("unavailable" if not available else "complete")
        ),
        freshness=freshness,
        sources=sources or [],
        missingMetrics=missing_metrics or [],
        generatedAt=generated_at,
        hourly=hourly,
        windows=windows,
        recommendedStart=recommended,
        personalLoadScore=load_score if personal_load is not None else None,
        personalLoadLevel=load_level,
        personalLoadReasonCodes=load_reasons,
    )
