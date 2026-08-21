#!/usr/bin/env python3
"""Authenticated Forecast Truth smoke against a live API.

This does not run as part of the local code-complete gate. After the 1.1
backend is deployed to api.hiair.io, pass a real user token and profile:

  HIAIR_ACCESS_TOKEN=... HIAIR_PROFILE_ID=... \\
    python scripts/release/smoke_forecast_truth.py --require-hourly
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def _get(url: str, token: str) -> tuple[int, dict | list | str]:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "HiAir-Forecast-Smoke/1.1",
            "Accept": "application/json",
            "Authorization": f"Bearer {token}",
        },
        method="GET",
    )
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


def _fail(name: str, detail: str) -> None:
    print(f"{name}: FAIL {detail}")


def _ok(name: str, detail: str) -> None:
    print(f"{name}: OK {detail}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Forecast Truth live smoke")
    parser.add_argument(
        "--base-url",
        default=os.getenv("HIAIR_API_BASE_URL", "https://api.hiair.io"),
    )
    parser.add_argument("--token", default=os.getenv("HIAIR_ACCESS_TOKEN", "").strip())
    parser.add_argument("--profile-id", default=os.getenv("HIAIR_PROFILE_ID", "").strip())
    parser.add_argument(
        "--require-hourly",
        action="store_true",
        help="Fail if day-plan hourlyRisk is empty (Open-Meteo should supply hours)",
    )
    args = parser.parse_args()
    if not args.token or not args.profile_id:
        print(
            "Forecast Truth production smoke: NOT RUN "
            "(set HIAIR_ACCESS_TOKEN and HIAIR_PROFILE_ID after backend deploy)."
        )
        return 2

    base = args.base_url.rstrip("/")
    failed = 0
    query = urllib.parse.urlencode({"profileId": args.profile_id})

    status, current = _get(f"{base}/api/air/current-risk?{query}", args.token)
    if status != 200 or not isinstance(current, dict):
        _fail("current-risk", f"status={status} body={current!r}")
        return 1
    env = current.get("environmental") if isinstance(current.get("environmental"), dict) else {}
    source = str(env.get("source") or current.get("freshness") or "")
    if source.lower() in {"sample", "mock"}:
        _fail("current-risk", f"protected production returned source={source}")
        failed = 1
    else:
        _ok("current-risk", f"source={source or 'unset'} freshness={current.get('freshness')}")

    status, plan = _get(f"{base}/api/air/day-plan?{query}", args.token)
    if status == 402:
        _ok("day-plan", "premium required (gate unchanged)")
        return failed
    if status != 200 or not isinstance(plan, dict):
        _fail("day-plan", f"status={status} body={plan!r}")
        return 1
    hourly = plan.get("hourlyRisk") if isinstance(plan.get("hourlyRisk"), list) else []
    windows = plan.get("safeWindows") if isinstance(plan.get("safeWindows"), list) else []
    timezone = str(plan.get("timezone") or "")
    if args.require_hourly and not hourly:
        _fail("day-plan", "hourlyRisk empty")
        failed = 1
    else:
        _ok(
            "day-plan",
            f"hours={len(hourly)} windows={len(windows)} tz={timezone or 'unset'} "
            f"quality={plan.get('dataQuality')} available={plan.get('forecastAvailable')}",
        )
    return failed


if __name__ == "__main__":
    sys.exit(main())
