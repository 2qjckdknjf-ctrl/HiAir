import json
import logging

import httpx

from app.core.settings import settings
from app.models.air import RecommendationCard, RiskAssessmentResult, UserProfileContext
from app.services.localization import normalize_language, t
from app.services.ai_observability_repository import ensure_prompt_version, save_explanation_event
from app.services.observability import record_ai_explanation

logger = logging.getLogger("hiair.ai.explanation")

FORBIDDEN_PHRASES = (
    "диагноз",
    "лечение",
    "приступ",
    "срочно",
    "medical condition",
    "diagnosis",
    "emergency",
    "treatment",
)
PROMPT_KEY = "air_explanation_ru"


def _classify_llm_failure(exc: Exception) -> str:
    if isinstance(exc, httpx.TimeoutException):
        return "llm_timeout"
    if isinstance(exc, httpx.ConnectError):
        return "llm_network_error"
    if isinstance(exc, httpx.HTTPStatusError):
        status_code = exc.response.status_code
        if status_code >= 500:
            return "llm_server_error"
        return "llm_http_error"
    if isinstance(exc, httpx.RequestError):
        return "llm_network_error"
    return "llm_request_failed"


def _fallback_explanation(risk: RiskAssessmentResult, recommendation: RecommendationCard, language: str) -> str:
    lang = normalize_language(language)
    action = recommendation.actions[0] if recommendation.actions else "-"
    return t(lang, "expl.fallback", risk=risk.overallRisk.value, summary=recommendation.summary, action=action)


def _is_safe_explanation(text: str) -> bool:
    normalized = text.lower()
    return not any(phrase in normalized for phrase in FORBIDDEN_PHRASES)


def generate_explanation(
    profile: UserProfileContext,
    risk: RiskAssessmentResult,
    recommendation: RecommendationCard,
    language: str = "ru",
    risk_assessment_id: str | None = None,
) -> tuple[str, str]:
    lang = normalize_language(language)
    system_prompt = (
        "You are a wellness assistant for heat and air quality context. "
        "Use only provided facts. No medical claims."
    )
    user_instruction = t(lang, "expl.user_instruction")
    try:
        ensure_prompt_version(
            prompt_key=PROMPT_KEY,
            version=settings.openai_prompt_version,
            prompt_text=f"{system_prompt}\n{user_instruction}",
        )
    except Exception:
        logger.exception("failed_to_register_prompt_version")

    if not settings.openai_api_key:
        fallback_text = _fallback_explanation(risk, recommendation, lang)
        record_ai_explanation(used_fallback=True, guardrail_blocked=False)
        try:
            save_explanation_event(
                profile_id=profile.profile_id,
                risk_assessment_id=risk_assessment_id,
                prompt_key=PROMPT_KEY,
                prompt_version=settings.openai_prompt_version,
                model_name=settings.openai_model,
                used_fallback=True,
                guardrail_blocked=False,
                failure_reason="missing_openai_api_key",
                generated_text=fallback_text,
            )
        except Exception:
            logger.exception("failed_to_save_ai_event")
        return fallback_text, "template_fallback"

    prompt_payload = {
        "profile_type": profile.profile_type.value,
        "overall_risk": risk.overallRisk.value,
        "heat_risk": risk.heatRisk.value,
        "air_risk": risk.airRisk.value,
        "recommendation_headline": recommendation.headline,
        "recommendation_actions": recommendation.actions,
        "guardrails": [
            "No diagnosis",
            "No treatment advice",
            "No emergency claims",
            "Action-first, calm tone",
            "Max 2 short sentences",
        ],
        "target_language": lang,
    }

    request_body = {
        "model": settings.openai_model,
        "messages": [
            {
                "role": "system",
                "content": system_prompt,
            },
            {
                "role": "user",
                "content": (
                    f"{user_instruction} Use {t(lang, 'expl.prompt.language')} only.\n"
                    f"Structured input:\n{json.dumps(prompt_payload, ensure_ascii=False)}"
                ),
            },
        ],
        "temperature": 0.2,
        "max_tokens": 120,
    }

    headers = {
        "Authorization": f"Bearer {settings.openai_api_key}",
        "Content-Type": "application/json",
    }

    try:
        with httpx.Client(timeout=8.0) as client:
            response = client.post(settings.openai_base_url, json=request_body, headers=headers)
            response.raise_for_status()
            payload = response.json()
        content = payload["choices"][0]["message"]["content"].strip()
        if not content or not _is_safe_explanation(content):
            logger.warning("unsafe_or_empty_explanation_output")
            fallback_text = _fallback_explanation(risk, recommendation, lang)
            record_ai_explanation(used_fallback=True, guardrail_blocked=True)
            try:
                save_explanation_event(
                    profile_id=profile.profile_id,
                    risk_assessment_id=risk_assessment_id,
                    prompt_key=PROMPT_KEY,
                    prompt_version=settings.openai_prompt_version,
                    model_name=settings.openai_model,
                    used_fallback=True,
                    guardrail_blocked=True,
                    failure_reason="unsafe_or_empty_output",
                    generated_text=fallback_text,
                )
            except Exception:
                logger.exception("failed_to_save_ai_event")
            return fallback_text, "template_fallback"
        record_ai_explanation(used_fallback=False, guardrail_blocked=False)
        try:
            save_explanation_event(
                profile_id=profile.profile_id,
                risk_assessment_id=risk_assessment_id,
                prompt_key=PROMPT_KEY,
                prompt_version=settings.openai_prompt_version,
                model_name=settings.openai_model,
                used_fallback=False,
                guardrail_blocked=False,
                failure_reason=None,
                generated_text=content,
            )
        except Exception:
            logger.exception("failed_to_save_ai_event")
        return content, "llm"
    except Exception as exc:
        logger.exception("llm_explanation_failed")
        fallback_text = _fallback_explanation(risk, recommendation, lang)
        record_ai_explanation(used_fallback=True, guardrail_blocked=False)
        failure_reason = _classify_llm_failure(exc)
        try:
            save_explanation_event(
                profile_id=profile.profile_id,
                risk_assessment_id=risk_assessment_id,
                prompt_key=PROMPT_KEY,
                prompt_version=settings.openai_prompt_version,
                model_name=settings.openai_model,
                used_fallback=True,
                guardrail_blocked=False,
                failure_reason=failure_reason,
                generated_text=fallback_text,
            )
        except Exception:
            logger.exception("failed_to_save_ai_event")
        return fallback_text, "template_fallback"
