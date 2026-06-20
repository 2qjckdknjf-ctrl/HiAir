from datetime import datetime

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


def _find_avoid_window(hourly) -> str | None:
    high_hours: list[str] = []
    for item in hourly:
        level = item.overallRisk.value if hasattr(item.overallRisk, "value") else str(item.overallRisk)
        if level in ("high", "very_high"):
            try:
                hour = datetime.fromisoformat(item.hour.replace("Z", "+00:00")).strftime("%H:%M")
                high_hours.append(hour)
            except ValueError:
                continue
    if not high_hours:
        return None
    return f"{high_hours[0]}–{high_hours[-1]}"


def build_morning_briefing_for_profile(
    profile: UserProfileContext,
    language: str,
    symptoms: SymptomInput,
    wearable: WearableMetricsResponse | None = None,
) -> MorningBriefingResponse:
    lang = normalize_language(language)
    environment = air_environment_service.load_environment(profile, force_live=False)
    risk = air_risk_engine.evaluate_risk(profile, environment)
    day_plan = air_risk_engine.build_day_plan(profile, environment)

    env_snapshot = EnvironmentSnapshot(
        temperature_c=environment.temperature,
        humidity_percent=environment.humidity,
        aqi=environment.aqi,
        pm25=environment.pm25,
        ozone=environment.ozone,
        source=environment.source,
    )
    persona = PersonaType.ADULT
    profile_type_value = profile.profile_type.value
    if profile_type_value.startswith("adult"):
        persona = PersonaType.ADULT
    elif profile_type_value == "child":
        persona = PersonaType.CHILD
    elif profile_type_value == "elderly":
        persona = PersonaType.ELDERLY
    elif "asthma" in profile_type_value:
        persona = PersonaType.ASTHMA
    elif "allergy" in profile_type_value:
        persona = PersonaType.ALLERGY
    elif profile_type_value == "runner":
        persona = PersonaType.RUNNER

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

    risk_label = t(lang, f"briefing.risk.{risk.overallRisk.value}", default=risk.overallRisk.value)
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
        risk_level=risk.overallRisk.value,
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
    avoid_window = None
    if high_hours:
        avoid_window = _format_window(high_hours[0], high_hours[-1])

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
        risk_score=score if score else breakdown.total_score,
        temperature_c=environment.temperature_c,
        aqi=environment.aqi,
        summary=summary,
        best_walk_window=walk_window,
        avoid_outdoor_window=avoid_window,
        personal_note=personal_note,
        wearable_note=None,
    )
