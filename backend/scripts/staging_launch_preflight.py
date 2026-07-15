#!/usr/bin/env python3
"""Staging readiness checks for the first-10-users launch sprint."""

from __future__ import annotations

import argparse
import os
import secrets
from pathlib import Path

import httpx


def main() -> int:
    parser = argparse.ArgumentParser(description="Run staging launch readiness checks.")
    parser.add_argument(
        "--base-url",
        default=os.getenv("HIAIR_STAGING_API_BASE_URL", "http://127.0.0.1:8000"),
        help="Staging API base URL",
    )
    args = parser.parse_args()

    failed: list[str] = []
    base = args.base_url.rstrip("/")

    migration_checks = [
        ("sql/006_wearable_metrics.sql", "CREATE TABLE IF NOT EXISTS wearable_metrics"),
        ("sql/006_wearable_metrics_rollback.sql", "DROP TABLE IF EXISTS wearable_metrics"),
        ("sql/007_launch_analytics.sql", "CREATE TABLE IF NOT EXISTS product_analytics_events"),
        ("sql/007_launch_analytics_rollback.sql", "DROP TABLE IF EXISTS product_analytics_events"),
    ]
    for relative_path, needle in migration_checks:
        path = Path(relative_path)
        if not path.exists():
            print(f"[FAIL] missing migration file {relative_path}")
            failed.append(relative_path)
            continue
        content = path.read_text(encoding="utf-8")
        if needle not in content:
            print(f"[FAIL] migration contract {relative_path}")
            failed.append(relative_path)
        else:
            print(f"[OK] migration contract {relative_path}")

    public_checks = [
        ("/api/health", 200),
        ("/api/insights/morning-briefing/public?persona=adult&lat=41.39&lon=2.17&language=ru", 200),
        ("/api/insights/risk-breakdown/public?persona=adult&lat=41.39&lon=2.17", 200),
        ("/api/planner/daily?persona=adult&lat=41.39&lon=2.17&hours=12", 200),
    ]

    with httpx.Client(timeout=10.0) as client:
        for path, expected in public_checks:
            url = f"{base}{path}"
            try:
                response = client.get(url)
                ok = response.status_code == expected
            except httpx.HTTPError:
                ok = False
                response = None
            if ok:
                print(f"[OK] {path}")
            else:
                status = response.status_code if response is not None else "connection_error"
                print(f"[FAIL] {path} (status={status})")
                failed.append(path)

        email = f"staging-{secrets.token_hex(5)}@hiair.app"
        password = "strongpass123"
        signup = client.post(f"{base}/api/auth/signup", json={"email": email, "password": password})
        if signup.status_code != 200:
            print(f"[FAIL] /api/auth/signup (status={signup.status_code})")
            failed.append("/api/auth/signup")
            return _finish(failed)

        token = signup.json().get("access_token")
        headers = {"Authorization": f"Bearer {token}"}
        print("[OK] /api/auth/signup")

        profile = client.post(
            f"{base}/api/profiles",
            headers=headers,
            json={
                "persona_type": "adult",
                "sensitivity_level": "medium",
                "home_lat": 41.39,
                "home_lon": 2.17,
            },
        )
        if profile.status_code != 200:
            print(f"[FAIL] /api/profiles (status={profile.status_code})")
            failed.append("/api/profiles")
            return _finish(failed)
        profile_id = profile.json().get("id")
        print("[OK] /api/profiles")

        authed_checks = [
            (
                "GET",
                f"/api/dashboard/overview?persona=adult&lat=41.39&lon=2.17&profile_id={profile_id}",
                None,
            ),
            (
                "GET",
                f"/api/insights/morning-briefing?persona=adult&lat=41.39&lon=2.17&profile_id={profile_id}",
                None,
            ),
            (
                "GET",
                f"/api/insights/risk-breakdown?persona=adult&lat=41.39&lon=2.17&profile_id={profile_id}",
                None,
            ),
            (
                "GET",
                f"/api/insights/personal-patterns?profile_id={profile_id}",
                None,
            ),
            ("GET", "/api/privacy/export", None),
            (
                "POST",
                "/api/analytics/events",
                {
                    "events": [
                        {
                            "session_id": "staging-check",
                            "event_name": "onboarding_started",
                            "platform": "staging",
                        }
                    ]
                },
            ),
            (
                "POST",
                "/api/feedback",
                {
                    "liked": "staging check",
                    "confusing": "",
                    "broken": "",
                    "platform": "staging",
                },
            ),
            (
                "POST",
                "/api/crashes/report",
                {
                    "message": "staging synthetic crash",
                    "stack_trace": "at staging.check",
                    "platform": "staging",
                },
            ),
            ("GET", "/api/analytics/kpi-dashboard?days=14", None),
        ]

        for method, path, payload in authed_checks:
            url = f"{base}{path}"
            try:
                if method == "GET":
                    response = client.get(url, headers=headers)
                else:
                    response = client.post(url, headers=headers, json=payload)
                ok = response.status_code in (200, 201)
            except httpx.HTTPError:
                ok = False
                response = None
            if ok:
                print(f"[OK] {method} {path}")
            else:
                status = response.status_code if response is not None else "connection_error"
                print(f"[FAIL] {method} {path} (status={status})")
                failed.append(path)

        delete = client.post(
            f"{base}/api/privacy/delete-account",
            headers=headers,
            json={"confirmation": "DELETE"},
        )
        if delete.status_code != 200:
            print(f"[FAIL] /api/privacy/delete-account (status={delete.status_code})")
            failed.append("/api/privacy/delete-account")
        else:
            print("[OK] /api/privacy/delete-account")

    return _finish(failed)


def _finish(failed: list[str]) -> int:
    if failed:
        print("Staging launch readiness failed.")
        for item in failed:
            print(f"- {item}")
        return 1
    print("Staging launch readiness passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
