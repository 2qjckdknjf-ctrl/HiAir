#!/usr/bin/env python3
"""Smoke-check the live HiAir API after Cloudflare deploy."""

from __future__ import annotations

import argparse
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request


def _ssl_context() -> ssl.SSLContext:
    try:
        import certifi

        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return ssl.create_default_context()


def _get(url: str, headers: dict[str, str] | None = None) -> tuple[int, dict | list | str]:
    merged = {"User-Agent": "HiAir-Deploy-Smoke/1.0", "Accept": "application/json"}
    if headers:
        merged.update(headers)
    req = urllib.request.Request(url, headers=merged, method="GET")
    last_error: Exception | None = None
    for attempt in range(1, 4):
        try:
            with urllib.request.urlopen(req, timeout=60, context=_ssl_context()) as resp:
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
        except (TimeoutError, urllib.error.URLError) as exc:
            last_error = exc
            if attempt < 3:
                time.sleep(8 * attempt)
                continue
            raise
    raise last_error or RuntimeError(f"GET failed: {url}")


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
    parser.add_argument(
        "--expect-sha",
        default=os.getenv("GITHUB_SHA", "").strip(),
        help="Require /api/health deploy_git_sha to match this commit (prefix OK)",
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

    expect_sha = (args.expect_sha or "").strip()
    if expect_sha:
        got_sha = str(health.get("deploy_git_sha") or "").strip()
        prefix = expect_sha[:12]
        if not got_sha or (got_sha != expect_sha and not got_sha.startswith(prefix)):
            print(
                f"deploy_git_sha: FAIL expected prefix {prefix} "
                f"got {got_sha or '(missing)'}"
            )
            return 1
        print(f"deploy_git_sha: OK {got_sha[:12]}…")

    # Production must never serve synthetic sample/mock air data via public API.
    status, sample = _get(
        f"{base}/api/environment/snapshot?lat=41.28&lon=1.98&source=sample"
    )
    if status == 200 and isinstance(sample, dict) and sample.get("source") in ("sample", "mock"):
        print(f"environment-sample: FAIL production served synthetic data payload={sample!r}")
        return 1
    if status not in (400, 403, 404, 422, 503):
        print(f"environment-sample: FAIL expected rejection, got status={status} body={sample}")
        return 1
    print(f"environment-sample: OK rejected status={status}")

    status, env_snap = _get(
        f"{base}/api/environment/snapshot?lat=41.28&lon=1.98&source=cached"
    )
    if status == 200:
        if not isinstance(env_snap, dict):
            print(f"environment-cached: FAIL unexpected payload={env_snap!r}")
            return 1
        src = str(env_snap.get("source") or "").strip().lower()
        if src in ("sample", "mock"):
            print(f"environment-cached: FAIL synthetic source={src}")
            return 1
        if src not in ("live", "cached"):
            print(f"environment-cached: FAIL unexpected source={src}")
            return 1
        print(f"environment-cached: OK source={src}")
    elif status == 503:
        print("environment-cached: OK unavailable (live/cache miss, sample disabled)")
    else:
        print(f"environment-cached: FAIL status={status} body={env_snap}")
        return 1

    status, export_unauth = _get(f"{base}/api/privacy/export")
    if status == 402:
        print("privacy-export: FAIL premium gate still active (402)")
        return 1
    if status != 401:
        print(f"privacy-export: FAIL expected 401 without auth, got {status} body={export_unauth}")
        return 1
    print("privacy-export: OK (401 without auth, no premium gate)")

    if not admin_token:
        if args.require_live_ai:
            print("ai-summary: FAIL NOTIFICATION_ADMIN_TOKEN required with --require-live-ai")
            return 1
        print("ai-summary: SKIP (NOTIFICATION_ADMIN_TOKEN not set)")
        print("post_deploy_api_smoke: PASS")
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
