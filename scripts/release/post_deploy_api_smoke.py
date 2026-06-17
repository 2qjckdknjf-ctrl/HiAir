#!/usr/bin/env python3
"""Smoke-check the live HiAir API after Cloudflare deploy."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request


def _get(url: str, headers: dict[str, str] | None = None) -> tuple[int, dict | list | str]:
    merged = {"User-Agent": "HiAir-Deploy-Smoke/1.0", "Accept": "application/json"}
    if headers:
        merged.update(headers)
    req = urllib.request.Request(url, headers=merged, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8")
            try:
                return resp.status, json.loads(body)
            except json.JSONDecodeError:
                return resp.status, body
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            payload: dict | list | str = json.loads(body)
        except json.JSONDecodeError:
            payload = body
        return exc.code, payload


def main() -> int:
    parser = argparse.ArgumentParser(description="Post-deploy smoke for https://api.hiair.io")
    parser.add_argument(
        "--base-url",
        default=os.getenv("HIAIR_API_BASE_URL", "https://api.hiair.io"),
        help="Production API base URL",
    )
    parser.add_argument(
        "--require-live-ai",
        action="store_true",
        help="Fail unless ai-summary reports provider_configured and llm_success_count >= 1",
    )
    args = parser.parse_args()
    base = args.base_url.rstrip("/")
    admin_token = os.getenv("NOTIFICATION_ADMIN_TOKEN", "").strip()

    status, health = _get(f"{base}/api/health")
    if status != 200:
        print(f"health: FAIL status={status} body={health}")
        return 1
    if not isinstance(health, dict) or health.get("status") != "ok":
        print(f"health: FAIL unexpected payload={health!r}")
        return 1
    print("health: OK")

    if not admin_token:
        print("ai-summary: SKIP (NOTIFICATION_ADMIN_TOKEN not set)")
        return 0

    status, summary = _get(
        f"{base}/api/observability/ai-summary?hours=24",
        headers={"X-Admin-Token": admin_token},
    )
    if status != 200:
        print(f"ai-summary: FAIL status={status} body={summary}")
        return 1
    if not isinstance(summary, dict):
        print(f"ai-summary: FAIL unexpected payload={summary!r}")
        return 1

    provider_configured = bool(summary.get("provider_configured"))
    llm_success = int(summary.get("llm_success_count") or 0)
    print(f"ai-summary: provider_configured={provider_configured} llm_success_count={llm_success}")

    if args.require_live_ai:
        if not provider_configured:
            print("ai-live: FAIL provider not configured on production API")
            return 1
        if llm_success < 1:
            print("ai-live: FAIL no llm_success_count in 24h window on production API")
            return 1
        print("ai-live: OK")

    print("post_deploy_api_smoke: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
