#!/usr/bin/env python3
"""Persist one live LLM explanation event for observability gate verification."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.models.air import RecommendationCard, RiskAssessmentResult, RiskLevel
from app.services import ai_explanation_service
from app.services.db import get_connection
import app.services.air_repository as air_repository


def _resolve_profile_id(explicit: str | None) -> str:
    if explicit:
        return explicit
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id::text AS id
                FROM profiles
                ORDER BY created_at DESC NULLS LAST
                LIMIT 1
                """
            )
            row = cur.fetchone()
    if row is None:
        raise RuntimeError("No profiles found; create a profile before seeding AI probe.")
    raw = row["id"]
    return raw.decode() if isinstance(raw, bytes) else str(raw)


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed one live LLM ai_explanation_events row.")
    parser.add_argument("--profile-id", default=None, help="Optional profile UUID to attach the event to.")
    args = parser.parse_args()

    profile_id = _resolve_profile_id(args.profile_id)
    profile = air_repository.get_profile_context(profile_id)
    if profile is None:
        print(f"Profile not found: {profile_id}")
        return 1

    risk = RiskAssessmentResult(
        overallRisk=RiskLevel.MODERATE,
        heatRisk=RiskLevel.MODERATE,
        airRisk=RiskLevel.LOW,
        outdoorRisk=RiskLevel.MODERATE,
        indoorVentilationRisk=RiskLevel.LOW,
        safeWindows=[],
        recommendationFlags=[],
        reasonCodes=["moderate_heat"],
    )
    recommendation = RecommendationCard(
        headline="Moderate conditions",
        summary="Normal precautions apply.",
        actions=["Short walks are acceptable."],
    )

    text, source = ai_explanation_service.generate_explanation(
        profile=profile,
        risk=risk,
        recommendation=recommendation,
        language="ru",
        risk_assessment_id=None,
    )
    print(f"profile_id={profile_id}")
    print(f"explanationSource={source}")
    print(f"explanation_preview={text[:120]}")
    return 0 if source == "llm" else 1


if __name__ == "__main__":
    raise SystemExit(main())
