import argparse
import os
import secrets

import httpx


def main() -> int:
    parser = argparse.ArgumentParser(description="Run beta API preflight checks.")
    parser.add_argument(
        "--base-url",
        default="http://127.0.0.1:8000",
        help="Backend API base URL",
    )
    parser.add_argument(
        "--admin-token",
        default=os.getenv("NOTIFICATION_ADMIN_TOKEN", ""),
        help="Optional admin token for protected ops endpoints (X-Admin-Token).",
    )
    parser.add_argument(
        "--skip-authenticated-checks",
        action="store_true",
        help="Skip authenticated endpoint checks (useful when local DB/auth stack is unavailable).",
    )
    args = parser.parse_args()

    checks = [
        ("/api/health", 200),
        ("/api/notifications/provider-health", 200),
        ("/api/notifications/secret-store-health", 200),
        ("/api/notifications/credentials-health", 200),
        ("/api/observability/metrics", 200),
        ("/api/validation/risk/historical", 200),
    ]

    failed = []
    admin_headers = {"X-Admin-Token": args.admin_token} if args.admin_token else {}
    with httpx.Client(timeout=6.0) as client:
        for path, expected_status in checks:
            url = f"{args.base_url.rstrip('/')}{path}"
            try:
                response = client.get(url, headers=admin_headers)
                ok = response.status_code == expected_status
            except httpx.HTTPError:
                ok = False
                response = None

            if ok:
                print(f"[OK] {path}")
            else:
                status = response.status_code if response is not None else "connection_error"
                print(f"[FAIL] {path} (status={status})")
                failed.append(path)

    if failed:
        print("Preflight failed.")
        for path in failed:
            print(f"- {path}")
        return 1

    if args.skip_authenticated_checks:
        print("Skipping authenticated checks (--skip-authenticated-checks).")
    else:
        auth_status = _run_authenticated_checks(args.base_url)
        if auth_status != 0:
            return auth_status

    print("Preflight passed.")
    return 0


def _run_authenticated_checks(base_url: str) -> int:
    base = base_url.rstrip("/")
    email = f"preflight-{_random_suffix()}@hiair.app"
    password = "strongpass123"

    with httpx.Client(timeout=8.0) as client:
        signup = client.post(
            f"{base}/api/auth/signup",
            json={"email": email, "password": password},
        )
        if signup.status_code != 200:
            print(f"[FAIL] /api/auth/signup (status={signup.status_code})")
            return 1
        token = signup.json().get("access_token")
        if not token:
            print("[FAIL] /api/auth/signup missing access_token")
            return 1

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
            return 1
        profile_id = profile.json().get("id")
        print("[OK] /api/profiles")

        activate = client.post(
            f"{base}/api/subscriptions/activate",
            headers=headers,
            json={"plan_id": "basic_monthly", "use_trial": True},
        )
        if activate.status_code != 200:
            print(f"[FAIL] /api/subscriptions/activate (status={activate.status_code})")
            return 1
        print("[OK] /api/subscriptions/activate")

        rec = client.get(
            f"{base}/api/recommendations/daily",
            headers=headers,
            params={"profile_id": profile_id},
        )
        if rec.status_code != 200:
            print(f"[FAIL] /api/recommendations/daily (status={rec.status_code})")
            return 1
        print("[OK] /api/recommendations/daily")

        briefing_get = client.get(f"{base}/api/briefings/schedule", headers=headers)
        if briefing_get.status_code != 200:
            print(f"[FAIL] /api/briefings/schedule GET (status={briefing_get.status_code})")
            return 1
        briefing_put = client.put(
            f"{base}/api/briefings/schedule",
            headers=headers,
            json={"local_time": "07:30", "enabled": True},
        )
        if briefing_put.status_code != 200:
            print(f"[FAIL] /api/briefings/schedule PUT (status={briefing_put.status_code})")
            return 1
        print("[OK] /api/briefings/schedule")

        insights = client.get(
            f"{base}/api/insights/personal-patterns",
            headers=headers,
            params={"profile_id": profile_id, "window_days": 30, "language": "en"},
        )
        if insights.status_code != 200:
            print(f"[FAIL] /api/insights/personal-patterns (status={insights.status_code})")
            return 1
        print("[OK] /api/insights/personal-patterns")

        privacy_export = client.get(f"{base}/api/privacy/export", headers=headers)
        if privacy_export.status_code != 200:
            print(f"[FAIL] /api/privacy/export (status={privacy_export.status_code})")
            return 1
        print("[OK] /api/privacy/export")

        intruder_signup = client.post(
            f"{base}/api/auth/signup",
            json={"email": f"intruder-{_random_suffix()}@hiair.app", "password": password},
        )
        if intruder_signup.status_code != 200:
            print(f"[FAIL] intruder /api/auth/signup (status={intruder_signup.status_code})")
            return 1
        intruder_token = intruder_signup.json().get("access_token")
        intruder_headers = {"Authorization": f"Bearer {intruder_token}"}
        forbidden = client.get(
            f"{base}/api/risk/history",
            headers=intruder_headers,
            params={"profile_id": profile_id, "limit": 1},
        )
        if forbidden.status_code != 403:
            print(f"[FAIL] ownership guard /api/risk/history (status={forbidden.status_code})")
            return 1
        print("[OK] ownership guard /api/risk/history")

    return 0


def _random_suffix() -> str:
    return secrets.token_hex(5)


if __name__ == "__main__":
    raise SystemExit(main())
