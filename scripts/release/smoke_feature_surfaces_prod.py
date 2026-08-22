#!/usr/bin/env python3
"""Authenticated production smoke for HiAir 1.3–1.5 feature API surfaces."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from uuid import uuid4


def _request(
    method: str,
    url: str,
    *,
    headers: dict[str, str] | None = None,
    body: dict | None = None,
) -> tuple[int, dict | list | str]:
    payload = None
    merged = {"User-Agent": "HiAir-Feature-Surfaces-Smoke/1.0", "Accept": "application/json"}
    if headers:
        merged.update(headers)
    if body is not None:
        payload = json.dumps(body).encode("utf-8")
        merged["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=payload, headers=merged, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode("utf-8")
            try:
                return resp.status, json.loads(raw)
            except json.JSONDecodeError:
                return resp.status, raw
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            parsed: dict | list | str = json.loads(raw)
        except json.JSONDecodeError:
            parsed = raw
        return exc.code, parsed


def _supabase_signup(base: str, anon_key: str, email: str, password: str) -> tuple[str, str]:
    status, payload = _request(
        "POST",
        f"{base}/auth/v1/signup",
        headers={"apikey": anon_key, "Authorization": f"Bearer {anon_key}"},
        body={"email": email, "password": password},
    )
    if status not in (200, 201):
        raise RuntimeError(f"supabase signup failed status={status}")
    if not isinstance(payload, dict):
        raise RuntimeError("supabase signup returned non-json")
    user = payload.get("user") or {}
    user_id = str(user.get("id") or "")
    access_token = str(payload.get("access_token") or "")
    if not user_id or not access_token:
        raise RuntimeError("supabase signup missing user_id/access_token")
    return user_id, access_token


def main() -> int:
    parser = argparse.ArgumentParser(description="Feature surfaces production smoke")
    parser.add_argument("--base-url", default=os.getenv("HIAIR_API_BASE_URL", "https://api.hiair.io"))
    parser.add_argument("--supabase-url", default=os.getenv("SUPABASE_URL", "").strip())
    parser.add_argument("--supabase-anon-key", default=os.getenv("SUPABASE_ANON_KEY", "").strip())
    args = parser.parse_args()
    if not args.supabase_url or not args.supabase_anon_key:
        print("feature_surfaces_smoke: NOT RUN (set SUPABASE_URL and SUPABASE_ANON_KEY)")
        return 2

    base = args.base_url.rstrip("/")
    email = f"smoke-features-{uuid4().hex[:10]}@hiair-smoke.invalid"
    password = f"Smoke-{uuid4().hex}!"
    user_id, token = _supabase_signup(args.supabase_url, args.supabase_anon_key, email, password)
    auth = {"Authorization": f"Bearer {token}"}

    status, created = _request(
        "POST",
        f"{base}/api/profiles",
        headers=auth,
        body={
            "persona_type": "adult",
            "sensitivity_level": "medium",
            "home_lat": 41.39,
            "home_lon": 2.17,
        },
    )
    if status not in (200, 201) or not isinstance(created, dict):
        print(f"profiles-create: FAIL status={status} body={created}")
        return 1
    profile_id = str(created.get("id") or "")
    if not profile_id:
        print("profiles-create: FAIL missing id")
        return 1
    print(f"profiles-create: OK profile_id={profile_id[:8]}…")

    for name, path in [
        ("family-members", "/api/family/members"),
        ("family-risk-overview", "/api/family/risk-overview"),
        ("places-list", "/api/places"),
        ("hazards", f"/api/air/hazards?{urllib.parse.urlencode({'profileId': profile_id})}"),
    ]:
        status, body = _request("GET", f"{base}{path}", headers=auth)
        if status != 200:
            print(f"{name}: FAIL status={status} body={body}")
            return 1
        print(f"{name}: OK")

    day_plan_query = urllib.parse.urlencode({"profileId": profile_id})
    status, body = _request("GET", f"{base}/api/air/day-plan?{day_plan_query}", headers=auth)
    if status == 402:
        print("day-plan: OK premium gate (402)")
    elif status == 500:
        print(f"day-plan: FAIL unexpected 500 body={body}")
        return 1
    elif status != 200:
        print(f"day-plan: FAIL status={status} body={body}")
        return 1
    else:
        print("day-plan: OK (premium user or gate open)")

    adaptation_query = urllib.parse.urlencode({"profileId": profile_id})
    status, body = _request("GET", f"{base}/api/insights/adaptation?{adaptation_query}", headers=auth)
    if status == 402:
        print("adaptation: OK premium gate (402)")
    elif status != 200:
        print(f"adaptation: FAIL status={status} body={body}")
        return 1
    else:
        print("adaptation: OK")

    site_query = urllib.parse.urlencode({"lat": 41.39, "lon": 2.17, "workload": "moderate"})
    status, body = _request("GET", f"{base}/api/work/site-risk?{site_query}", headers=auth)
    if status != 200:
        print(f"work-site-risk: FAIL status={status} body={body}")
        return 1
    print("work-site-risk: OK")

    status, body = _request("GET", f"{base}/api/planner/activities", headers=auth)
    if status != 200:
        print(f"planner-activities: FAIL status={status} body={body}")
        return 1
    print("planner-activities: OK")

    print("feature_surfaces_production_smoke: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
