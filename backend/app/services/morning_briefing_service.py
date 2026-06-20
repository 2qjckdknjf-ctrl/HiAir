from datetime import datetime, timedelta

from app.models.air import SafeWindowType, UserProfileContext
from app.models.insights import MorningBriefingResponse
from app.models.risk import EnvironmentSnapshot, PersonaType, SymptomInput
from app.models.wearable import WearableMetricsResponse
from app.services.environment_service import build_mock_snapshot
from app.services.localization import normalize_language, t
import app.services.air_environment_service as air_environment_service
import app.services.air_risk_engine as air_risk_engine
from app.services.risk_breakdown_service import build_risk_breakdown
from app.services.risk_engine import estimate_risk


def _format_window(start_iso: str, end_iso: str) -> str:
    try:
        start = datetime.fromisoformat(start_iso.replace("Z", "+00:00"))
        end = datetime.fromisoformat(end_iso.replace("Z", "+00:00"))
        return f"{start.strftime('%H:%M')}–{end.strftime('%H:%M')}"
    except ValueError:
        return f"{start_iso}–{end_iso}"


def _parse_iso_datetime(value: str) -> datetime | None:
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _find_contiguous_window(high_hours: list[str]) -> str | None:
    best_start: str | None = None
    best_end: str | None = None
    best_length = 0
    current_start: str | None = None
    current_start_time: datetime | None = None
    previous_time: datetime | None = None

    for hour_iso in high_hours:
        current_time = _parse_iso_datetime(hour_iso)
        if current_time is None:
            current_start = None
            current_start_time = None
            previous_time = None
            continue

        if previous_time is None or current_time - previous_time > timedelta(hours=1):
            current_start = hour_iso
            current_start_time = current_time

        if current_start is None or current_start_time is None:
            previous_time = current_time
            continue

        current_length = int((current_time - current_start_time).total_seconds() // 3600) + 1
        if current_length > best_length:
            best_start = current_start
            best_end = hour_iso
            best_length = current_length

        previous_time = current_time

    if best_start is None or best_end is None:
        return None
    return _format_window(best_start, best_end)


def _find_avoid_window(hourly) -> str | None:
    high_hours = []
    for item in hourly:
        level = item.overallRisk.value if hasattr(item.overallRisk, "value") else str(item.overallRisk)
        if level in ("high", "very_high"):
            high_hours.append(item.hour)
    return _find_contiguous_window(high_hours)


def persona_for_profile(profile: UserProfileContext) -> PersonaType:
    profile_type_value = profile.profile_type.value
    if profile_type_value.startswith("adult"):
        return PersonaType.ADULT
    if profile_type_value == "child":
        return PersonaType.CHILD
    if profile_type_value == "elderly":
        return PersonaType.ELDERLY
    if "asthma" in profile_type_value:
        return PersonaType.ASTHMA
    if "allergy" in profile_type_value:
        return PersonaType.ALLERGY
    if profile_type_value == "runner":
        return PersonaType.RUNNER
    if profile_type_value == "outdoor_worker":
        return PersonaType.WORKER
    return PersonaType.ADULT


def build_morning_briefing_for_profile(
    profile: UserProfileContext,
    language: str,
    symptoms: SymptomInput,
    wearable: WearableMetricsResponse | None = None,
) -> MorningBriefingResponse:
    lang = normalize_language(language)
    environment = air_environment_service.load_environment(profile, force_live=False)
    day_plan = air_risk_engine.build_day_plan(profile, environment)

    env_snapshot = EnvironmentSnapshot(
        temperature_c=environment.temperature,
        humidity_percent=environment.humidity,
        aqi=environment.aqi,
        pm25=environment.pm25,
        ozone=environment.ozone,
        source=environment.source,
    )
    persona = persona_for_profile(profile)

    breakdown = build_risk_breakdown(
        profile_id=profile.profile_id,
        persona=persona,
        symptoms=symptoms,
        environment=env_snapshot,
        wearable=wearable,
    )

    walk_windows = [
        w for w in day_plan.safeWindows if w.type in (SafeWindowType.WALK, SafeWindowType.GENERAL_OUTDOOR)
    ]
    best_walk = _format_window(walk_windows[0].start, walk_windows[0].end) if walk_windows else None
    avoid_window = _find_avoid_window(day_plan.hourlyRisk)

    risk_label = t(lang, f"briefing.risk.{breakdown.risk_level}", default=breakdown.risk_level)
    summary = t(
        lang,
        "briefing.summary",
        risk=risk_label,
        temp=round(environment.temperature, 1),
        aqi=environment.aqi,
        walk=best_walk or t(lang, "briefing.no_walk_window"),
        avoid=avoid_window or t(lang, "briefing.no_avoid_window"),
    )
    personal_note = t(
        lang,
        "briefing.personal_note",
        risk=risk_label,
        walk=best_walk or t(lang, "briefing.no_walk_window"),
        avoid=avoid_window or t(lang, "briefing.no_avoid_window"),
    )

    wearable_note = None
    if wearable and (wearable.resting_heart_rate_bpm or wearable.sleep_hours or wearable.sleep_quality_score):
        wearable_note = t(lang, "briefing.wearable_context")

    return MorningBriefingResponse(
        profile_id=profile.profile_id,
        language=lang,
        risk_level=breakdown.risk_level,
        risk_score=breakdown.total_score,
        temperature_c=environment.temperature,
        aqi=environment.aqi,
        summary=summary,
        best_walk_window=best_walk,
        avoid_outdoor_window=avoid_window,
        personal_note=personal_note,
        wearable_note=wearable_note,
    )


def build_morning_briefing_guest(
    *,
    persona: str,
    lat: float,
    lon: float,
    language: str,
) -> MorningBriefingResponse:
    lang = normalize_language(language)
    persona_enum = PersonaType.ADULT
    try:
        persona_enum = PersonaType(persona.lower())
    except ValueError:
        persona_enum = PersonaType.ADULT

    environment = build_mock_snapshot(lat=lat, lon=lon)
    symptoms = SymptomInput()
    score, level, _, _ = estimate_risk(persona=persona_enum, symptoms=symptoms, environment=environment)
    breakdown = build_risk_breakdown(
        profile_id=None,
        persona=persona_enum,
        symptoms=symptoms,
        environment=environment,
    )

    from app.api.planner import daily_planner

    planner = daily_planner(persona=persona_enum.value, lat=lat, lon=lon, hours=24)
    walk_window = None
    if planner.safe_windows:
        walk_window = _format_window(planner.safe_windows[0].start_hour_iso, planner.safe_windows[0].end_hour_iso)

    high_hours = [item.hour_iso for item in planner.hourly if item.level in ("high", "very_high")]
    avoid_window = _find_contiguous_window(high_hours)

    risk_label = t(lang, f"briefing.risk.{level}", default=level)
    summary = t(
        lang,
        "briefing.summary",
        risk=risk_label,
        temp=round(environment.temperature_c, 1),
        aqi=environment.aqi,
        walk=walk_window or t(lang, "briefing.no_walk_window"),
        avoid=avoid_window or t(lang, "briefing.no_avoid_window"),
    )
    personal_note = t(
        lang,
        "briefing.personal_note",
        risk=risk_label,
        walk=walk_window or t(lang, "briefing.no_walk_window"),
        avoid=avoid_window or t(lang, "briefing.no_avoid_window"),
    )

    return MorningBriefingResponse(
        profile_id=None,
        language=lang,
        risk_level=level,
        risk_score=score,
        temperature_c=environment.temperature_c,
        aqi=environment.aqi,
        summary=summary,
        best_walk_window=walk_window,
        avoid_outdoor_window=avoid_window,
        personal_note=personal_note,
        wearable_note=None,
    )
