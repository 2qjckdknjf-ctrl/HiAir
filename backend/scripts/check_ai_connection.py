#!/usr/bin/env python3
"""Safe AI/LLM connectivity check — never prints secret values."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.settings import settings
from app.services.ai_observability_repository import ai_event_summary


def _mask(value: str) -> str:
    if not value:
        return "MISSING"
    return f"SET, length={len(value)}, prefix={value[:3]}***"


def main() -> int:
    parser = argparse.ArgumentParser(description="Check HiAir AI/LLM configuration and recent observability.")
    parser.add_argument("--hours", type=int, default=24, help="Observability window in hours (default: 24)")
    parser.add_argument(
        "--require-live",
        action="store_true",
        help="Exit non-zero unless at least one non-fallback LLM event exists in the window.",
    )
    parser.add_argument(
        "--skip-if-unconfigured",
        action="store_true",
        help="Exit 0 when OPENAI_API_KEY is missing (for CI without secrets).",
    )
    args = parser.parse_args()

    print("HiAir AI connection check")
    print("-----------------------")
    print(f"OPENAI_API_KEY: {_mask(settings.openai_api_key)}")
    print(f"OPENAI_MODEL: {settings.openai_model or 'MISSING'}")
    print(f"OPENAI_BASE_URL: {settings.openai_base_url or 'MISSING'}")
    print(f"OPENAI_PROMPT_VERSION: {settings.openai_prompt_version or 'MISSING'}")
    print(f"provider_configured: {bool(settings.openai_api_key.strip())}")
    print(f"expected_runtime_mode: {'live_llm' if settings.openai_api_key.strip() else 'template_fallback'}")

    try:
        summary = ai_event_summary(hours=args.hours)
    except Exception as exc:
        print(f"observability_db: UNAVAILABLE ({exc.__class__.__name__})")
        return 2

    total = int(summary.get("total") or 0)
    fallback = int(summary.get("fallback_count") or 0)
    llm_success = int(summary.get("llm_success_count") or 0)
    missing_key = int(summary.get("missing_key_count") or 0)
    print(f"observability_window_hours: {args.hours}")
    print(f"ai_events_total: {total}")
    print(f"fallback_count: {fallback}")
    print(f"llm_success_count: {llm_success}")
    print(f"missing_key_count: {missing_key}")
    print(f"guardrail_block_count: {int(summary.get('guardrail_block_count') or 0)}")

    if not settings.openai_api_key.strip():
        if args.skip_if_unconfigured:
            print("verdict: SKIP — OPENAI_API_KEY not configured.")
            return 0
        print("verdict: OWNER_ACTION_REQUIRED — set OPENAI_API_KEY to enable live LLM explanations.")
        return 1

    if args.require_live and llm_success < 1:
        print("verdict: NO-GO — key is set but no non-fallback LLM events in the selected window.")
        return 1

    if llm_success >= 1:
        print("verdict: GO — live LLM events observed.")
        return 0

    print("verdict: CONDITIONAL GO — key configured; trigger /api/air/current-risk to produce events.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
