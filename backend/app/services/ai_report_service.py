"""Human-language AI reports for morning / evening / weekly wellness digests.

Wellness-only. No diagnoses. No exact biometric values in logs.
"""

from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any, Literal

from fastapi import HTTPException
from psycopg.errors import UndefinedTable

import app.services.ai_explanation_service as ai_explanation_service
import app.services.air_environment_service as air_environment_service
import app.services.air_recommendation_engine as air_recommendation_engine
import app.services.air_repository as air_repository
import app.services.air_risk_engine as air_risk_engine
import app.services.entitlement_service as entitlement_service
import app.services.health_analytics_service as health_analytics_service
import app.services.settings_repository as settings_repository
import app.services.travel_location as travel_location
import app.services.wearable_repository as wearable_repository
import app.services.wearable_service as wearable_service
from app.services.forecast.mapping import (
    forecast_to_hourly_inputs,
    overlay_forecast_current,
)
from app.services.forecast.service import get_forecast
from app.services.localization import normalize_language

ReportKind = Literal["morning", "evening", "weekly"]


def _health_observations(user_id: str, profile_id: str, language: str, window_days: int) -> list[str]:
    try:
        consent = wearable_repository.get_active_consent(user_id)
    except UndefinedTable:
        return []
    if consent is None or not getattr(consent, "isActive", True):
        return []
    entitlement = entitlement_service.get_current_entitlement(user_id)
    if not entitlement.is_premium or not entitlement.advanced_insights_enabled:
        return []
    try:
        bundle = health_analytics_service.build_insights_bundle(
            user_id=user_id,
            profile_id=profile_id,
            window_days=window_days,
            language=language,
            require_active_consent=True,
        )
    except Exception:
        return []
    observations: list[str] = []
    for card in (bundle.get("associations") or [])[:2]:
        title = getattr(card, "title", None) or (card.get("title") if isinstance(card, dict) else None)
        observation = getattr(card, "observation", None) or (
            card.get("observation") if isinstance(card, dict) else None
        )
        if title and observation:
            observations.append(f"{title}: {observation}")
    for card in (bundle.get("trends") or [])[:2]:
        title = getattr(card, "title", None) or (card.get("title") if isinstance(card, dict) else None)
        observation = getattr(card, "observation", None) or (
            card.get("observation") if isinstance(card, dict) else None
        )
        if title and observation:
            observations.append(f"{title}: {observation}")
    return observations[:4]


def _template_report(
    *,
    kind: ReportKind,
    language: str,
    risk_level: str,
    headline: str,
    explanation: str,
    actions: list[str],
    load_level: str | None,
) -> str:
    lang = normalize_language(language)
    action = actions[0] if actions else ""
    load_bit = f" Recovery context: {load_level}." if load_level else ""
    if kind == "morning":
        if lang == "ru":
            return (
                f"Доброе утро. Сегодня риск {risk_level}. {headline} {explanation}{load_bit} "
                f"{('Сделайте: ' + action) if action else ''}".strip()
            )
        return (
            f"Good morning. Today's risk is {risk_level}. {headline} {explanation}{load_bit} "
            f"{('Start with: ' + action) if action else ''}".strip()
        )
    if kind == "evening":
        if lang == "ru":
            return (
                f"Вечерний итог: риск был {risk_level}. {explanation}{load_bit} "
                f"{('На завтра: ' + action) if action else ''}".strip()
            )
        return (
            f"Evening wrap-up: risk was {risk_level}. {explanation}{load_bit} "
            f"{('For tomorrow: ' + action) if action else ''}".strip()
        )
    if lang == "ru":
        return (
            f"Недельный обзор: актуальный риск {risk_level}. {explanation}{load_bit} "
            f"{('Фокус: ' + action) if action else ''}".strip()
        )
    return (
        f"Weekly overview: current risk {risk_level}. {explanation}{load_bit} "
        f"{('Focus: ' + action) if action else ''}".strip()
    )


def build_ai_report(
    *,
    user_id: str,
    profile_id: str,
    kind: ReportKind,
) -> dict[str, Any]:
    profile = air_repository.get_profile_context(profile_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.user_id != user_id:
        raise HTTPException(status_code=403, detail="Profile does not belong to user")

    if kind in ("evening", "weekly"):
        entitlement_service.require_feature(user_id, "advanced_insights", "advanced_insights_enabled")

    profile = travel_location.apply_travel_location_override(user_id, profile)
    user_settings = settings_repository.get_user_settings(user_id)
    language = user_settings.preferred_language
    environment = air_environment_service.load_environment(profile)
    forecast = None
    hourly_points: list = []
    try:
        forecast = get_forecast(profile.home_lat, profile.home_lon)
        hourly_points = forecast_to_hourly_inputs(forecast)
        environment = overlay_forecast_current(environment, forecast)
    except Exception:
        hourly_points = []
    personal_load = wearable_service.build_personal_load_input(user_id, environment)
    risk = air_risk_engine.evaluate_risk(
        profile,
        environment,
        personal_load,
        hourly_points=hourly_points,
    )
    recommendation = air_recommendation_engine.generate_recommendation(profile, risk, language=language)

    window_days = 7 if kind == "weekly" else 30
    health_context = _health_observations(user_id, profile_id, language, window_days)
    explanation, source = ai_explanation_service.generate_explanation(
        profile,
        risk,
        recommendation,
        language=language,
        risk_assessment_id=None,
        health_context=health_context,
    )

    load_summary = None
    try:
        today = wearable_service.build_today_response(user_id)
        if today.personalLoad is not None:
            load_summary = {
                "score": today.personalLoad.score,
                "level": today.personalLoad.level,
                "explanations": today.personalLoad.explanations[:3],
            }
    except Exception:
        load_summary = None

    narrative = _template_report(
        kind=kind,
        language=language,
        risk_level=risk.overallRisk.value,
        headline=recommendation.headline,
        explanation=explanation,
        actions=list(recommendation.actions or []),
        load_level=(load_summary or {}).get("level"),
    )
    # Prefer LLM explanation as the core narrative when live; wrap with kind framing.
    if source != "template_fallback" and explanation.strip():
        if kind == "morning":
            narrative = explanation.strip()
        elif kind == "evening":
            narrative = explanation.strip()
        else:
            narrative = explanation.strip()

    return {
        "kind": kind,
        "profileId": profile_id,
        "generatedAt": datetime.now(tz=timezone.utc),
        "localDate": date.today().isoformat(),
        "windowDays": window_days if kind == "weekly" else 1,
        "riskLevel": risk.overallRisk.value,
        "headline": recommendation.headline,
        "narrative": narrative,
        "actions": list(recommendation.actions or [])[:3],
        "healthContextPresent": bool(health_context),
        "healthObservationCount": len(health_context),
        "personalLoad": load_summary,
        "explanationSource": source,
        "environmentSource": getattr(environment, "source", None),
    }
