#!/usr/bin/env python3
"""Authenticated production smoke for HiAir 1.3–1.5 feature API surfaces."""

from __future__ import annotations

import argparse
import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from uuid import uuid4


def _ssl_context() -> ssl.SSLContext:
    try:
        import certifi

        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return ssl.create_default_context()


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
        with urllib.request.urlopen(req, timeout=30, context=_ssl_context()) as resp:
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
        ("travel-session", "/api/travel/session"),
        ("hazards", f"/api/air/hazards?{urllib.parse.urlencode({'profileId': profile_id})}"),
    ]:
        status, body = _request("GET", f"{base}{path}", headers=auth)
        if status != 200:
            print(f"{name}: FAIL status={status} body={body}")
            return 1
        if name == "travel-session":
            if not isinstance(body, dict) or "active" not in body:
                print(f"travel-session: FAIL missing active key body={body!r}")
                return 1
            print(f"travel-session: OK active={body.get('active')}")
            continue
        if name == "hazards":
            if not isinstance(body, dict):
                print(f"hazards: FAIL non-object body={body!r}")
                return 1
            assessment = body.get("assessment")
            if not isinstance(assessment, dict):
                print(f"hazards: FAIL missing assessment body={body!r}")
                return 1
            hazards = assessment.get("hazards")
            if not isinstance(hazards, list) or not hazards:
                print(f"hazards: FAIL empty hazards list body={assessment!r}")
                return 1
            by_type = {
                item.get("hazard"): item
                for item in hazards
                if isinstance(item, dict) and item.get("hazard")
            }
            for required in ("pollen", "smoke", "dust", "heat", "air", "uv"):
                item = by_type.get(required)
                if not isinstance(item, dict):
                    print(f"hazards: FAIL missing hazard={required} keys={sorted(by_type)}")
                    return 1
                available = bool(item.get("available"))
                level = item.get("level")
                if available:
                    if level == "unavailable":
                        print(f"hazards: FAIL {required} available but level=unavailable")
                        return 1
                else:
                    if level != "unavailable":
                        print(f"hazards: FAIL {required} unavailable but level={level!r}")
                        return 1
                    if not item.get("unavailableReason"):
                        print(f"hazards: FAIL {required} missing unavailableReason")
                        return 1
            env = body.get("environmental")
            if not isinstance(env, dict) or "pollen_grains_m3" not in env or "wildfire_pm10" not in env:
                print(f"hazards: FAIL environmental missing pollen/smoke keys body={env!r}")
                return 1
            pollen_state = "set" if env.get("pollen_grains_m3") is not None else "null"
            smoke_state = "set" if env.get("wildfire_pm10") is not None else "null"
            print(
                f"hazards: OK pollen={pollen_state} smoke={smoke_state} "
                f"types={len(by_type)}"
            )
            continue
        print(f"{name}: OK")

    risk_query = urllib.parse.urlencode({"profileId": profile_id})
    status, body = _request("GET", f"{base}/api/air/current-risk?{risk_query}", headers=auth)
    if status != 200 or not isinstance(body, dict):
        print(f"current-risk: FAIL status={status} body={body}")
        return 1
    environmental = body.get("environmental")
    if not isinstance(environmental, dict) or "no2" not in environmental:
        print(f"current-risk: FAIL environmental missing no2 key body={environmental!r}")
        return 1
    no2_value = environmental.get("no2")
    print(f"current-risk: OK no2={'set' if no2_value is not None else 'null'}")

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
    if status != 200 or not isinstance(body, dict):
        print(f"work-site-risk: FAIL status={status} body={body}")
        return 1
    assessment = body.get("assessment")
    if not isinstance(assessment, dict):
        print(f"work-site-risk: FAIL missing assessment body={body!r}")
        return 1
    reason_codes = assessment.get("reasonCodes")
    if not isinstance(reason_codes, list):
        print(f"work-site-risk: FAIL missing reasonCodes body={assessment!r}")
        return 1
    wbgt_c = assessment.get("wbgtC")
    if wbgt_c is not None:
        if "wbgt_estimated_from_meteo" in reason_codes and "not_instrument_wbgt" not in reason_codes:
            print(f"work-site-risk: FAIL estimated WBGT missing not_instrument_wbgt codes={reason_codes!r}")
            return 1
        if "wbgt_unavailable" in reason_codes:
            print(f"work-site-risk: FAIL wbgtC set with wbgt_unavailable codes={reason_codes!r}")
            return 1
        print(f"work-site-risk: OK wbgt=set estimated={'wbgt_estimated_from_meteo' in reason_codes}")
    else:
        if "wbgt_unavailable" not in reason_codes and "wbgt_assessment" in reason_codes:
            print(f"work-site-risk: FAIL null wbgt with wbgt_assessment codes={reason_codes!r}")
            return 1
        print("work-site-risk: OK wbgt=null (honest)")

    status, body = _request("GET", f"{base}/api/planner/activities", headers=auth)
    if status != 200:
        print(f"planner-activities: FAIL status={status} body={body}")
        return 1
    print("planner-activities: OK")

    status, body = _request(
        "POST",
        f"{base}/api/planner/activity-plan",
        headers=auth,
        body={
            "profileId": profile_id,
            "activity": "running",
            "durationMinutes": 45,
        },
    )
    if status == 402:
        print("activity-plan: OK premium gate (402)")
    elif status != 200:
        print(f"activity-plan: FAIL status={status} body={body}")
        return 1
    else:
        print("activity-plan: OK")

    status, body = _request(
        "POST",
        f"{base}/api/insights/protected-day-events",
        headers=auth,
        body={"profileId": profile_id, "eventType": "workout_moved"},
    )
    if status == 402:
        print("protected-day-events: OK premium gate (402)")
    elif status != 200:
        print(f"protected-day-events: FAIL status={status} body={body}")
        return 1
    else:
        print("protected-day-events: OK")

    status, body = _request(
        "POST",
        f"{base}/api/alerts/decide",
        headers=auth,
        body={
            "candidate": {
                "alertType": "air_worsening",
                "severity": "medium",
                "reasonCode": "threshold_crossed",
                "profileId": profile_id,
                "localHour": 10,
                "quietHoursStart": 22,
                "quietHoursEnd": 7,
                "cooldownMinutesRemaining": 0,
                "fingerprint": "smoke:test",
                "actionable": True,
                "personalThresholdMet": True,
            }
        },
    )
    if status != 200 or not isinstance(body, dict):
        print(f"alerts-decide: FAIL status={status} body={body}")
        return 1
    decision = body.get("decision") if isinstance(body.get("decision"), dict) else {}
    if decision.get("action") not in ("send", "suppress"):
        print(f"alerts-decide: FAIL unexpected decision={decision!r}")
        return 1
    print(f"alerts-decide: OK action={decision.get('action')}")

    print("feature_surfaces_production_smoke: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
