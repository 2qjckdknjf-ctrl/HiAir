#!/usr/bin/env python3
"""Offline benchmark harness for grounded explanation guardrails (no live LLM calls)."""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from types import SimpleNamespace

from app.models.air import (
    ProfileType,
    RecommendationCard,
    RiskAssessmentResult,
    RiskLevel,
    UserProfileContext,
)
from app.services import ai_explanation_service


@dataclass
class BenchmarkCase:
    name: str
    language: str
    freshness: str | None
    data_quality: str | None
    health_context: list[str]
    expect_source: str


CASES = [
    BenchmarkCase("ru_ok_template", "ru", None, "complete", ["recovery_band_low"], "template_fallback"),
    BenchmarkCase("es_stale_blocked", "es", "stale", "complete", [], "template_fallback"),
    BenchmarkCase("it_unavailable_blocked", "it", None, "unavailable", [], "template_fallback"),
    BenchmarkCase(
        "fr_raw_health_sanitized",
        "fr",
        None,
        "complete",
        ["lat=48.8566", "recovery_band_high"],
        "template_fallback",
    ),
]


def main() -> int:
    # Offline harness: never call a live provider.
    ai_explanation_service.settings = SimpleNamespace(
        openai_api_key="",
        openai_model="gpt-4o-mini",
        openai_base_url="https://api.openai.com/v1/chat/completions",
        openai_prompt_version="hiair-expl-v1",
        openai_rate_limit_per_minute=60,
        openai_http_timeout_seconds=8.0,
        openai_max_tokens=120,
    )
    ai_explanation_service.ensure_prompt_version = lambda **kwargs: None  # type: ignore[assignment]
    ai_explanation_service.save_explanation_event = lambda **kwargs: "bench"  # type: ignore[assignment]

    profile = UserProfileContext(
        profile_id="bench-1",
        user_id="user-1",
        profile_type=ProfileType.ADULT_DEFAULT,
        age_group="adult",
        heat_sensitivity_level=2,
        respiratory_sensitivity_level=2,
        activity_level="moderate",
        timezone="UTC",
        home_lat=41.39,
        home_lon=2.17,
    )
    risk = RiskAssessmentResult(
        overallRisk=RiskLevel.MODERATE,
        heatRisk=RiskLevel.MODERATE,
        airRisk=RiskLevel.MODERATE,
        outdoorRisk=RiskLevel.MODERATE,
        indoorVentilationRisk=RiskLevel.LOW,
        safeWindows=[],
        recommendationFlags=[],
        reasonCodes=[],
    )
    recommendation = RecommendationCard(headline="h", summary="s", actions=["hydrate"])
    results = []
    for case in CASES:
        text, source = ai_explanation_service.generate_explanation(
            profile,
            risk,
            recommendation,
            language=case.language,
            health_context=case.health_context,
            allow_llm=True,
            data_quality=case.data_quality,
            freshness=case.freshness,
        )
        payload = ai_explanation_service.build_prompt_payload(
            profile,
            risk,
            recommendation,
            language=case.language,
            health_context=case.health_context,
        )
        ok = source == case.expect_source and "lat=" not in str(payload)
        results.append({"case": asdict(case), "source": source, "ok": ok, "text_len": len(text)})
    print(json.dumps({"benchmark": "ai_explanation_guardrails", "results": results}, ensure_ascii=False, indent=2))
    return 0 if all(item["ok"] for item in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
