#!/usr/bin/env python3
"""Production subscription + privacy contract smoke for https://api.hiair.io."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
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
    merged = {"User-Agent": "HiAir-Subscription-Smoke/1.0", "Accept": "application/json"}
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
    parser = argparse.ArgumentParser(description="Subscription production smoke")
    parser.add_argument("--base-url", default=os.getenv("HIAIR_API_BASE_URL", "https://api.hiair.io"))
    parser.add_argument("--supabase-url", default=os.getenv("SUPABASE_URL", "").strip())
    parser.add_argument("--supabase-anon-key", default=os.getenv("SUPABASE_ANON_KEY", "").strip())
    args = parser.parse_args()

    base = args.base_url.rstrip("/")

    status, health = _get_health(base)
    if status != 200:
        print(f"health: FAIL status={status}")
        return 1
    print("health: OK")

    status, _ = _request("GET", f"{base}/api/privacy/export")
    if status == 402:
        print("privacy-export-unauth: FAIL premium gate active (402)")
        return 1
    if status != 401:
        print(f"privacy-export-unauth: FAIL expected 401 got {status}")
        return 1
    print("privacy-export-unauth: OK (401, no premium gate)")

    if not args.supabase_url or not args.supabase_anon_key:
        print("authenticated-contract: SKIP (SUPABASE_URL / SUPABASE_ANON_KEY not set)")
        print("subscription_production_smoke: PARTIAL PASS")
        return 0

    email = f"smoke-{uuid4().hex[:10]}@hiair.app"
    password = f"StrongPass{uuid4().hex[:8]}!"
    try:
        user_id, access_token = _supabase_signup(args.supabase_url, args.supabase_anon_key, email, password)
    except RuntimeError as exc:
        print(f"authenticated-contract: SKIP ({exc})")
        print("subscription_production_smoke: PARTIAL PASS")
        return 0

    auth = {"Authorization": f"Bearer {access_token}"}

    status, me = _request("GET", f"{base}/api/subscriptions/me", headers=auth)
    if status != 200:
        print(f"subscriptions-me: FAIL status={status} body={me}")
        return 1
    entitlement = me.get("entitlement", {}) if isinstance(me, dict) else {}
    is_premium = bool(entitlement.get("is_premium"))
    if is_premium:
        print("subscriptions-me: FAIL unexpected premium for fresh user")
        return 1
    print("subscriptions-me-free: OK is_premium=false")

    status, export_payload = _request("GET", f"{base}/api/privacy/export", headers=auth)
    if status == 402:
        print("privacy-export-auth: FAIL premium gate (402)")
        return 1
    if status == 404:
        print("privacy-export-auth: OK (404 user not provisioned in API DB yet; no premium gate)")
    elif status != 200:
        print(f"privacy-export-auth: FAIL status={status} body={export_payload}")
        return 1
    else:
        print("privacy-export-auth: OK (200 for authenticated user)")

    status, planner = _request(
        "GET",
        f"{base}/api/planner/daily?profile_id=missing-profile",
        headers=auth,
    )
    if status not in (402, 404):
        print(f"planner-free: FAIL expected 402/404 got {status} body={planner}")
        return 1
    if status == 402:
        print("planner-free: OK (402 premium required)")
    else:
        print("planner-free: OK (404 profile missing before premium gate)")

    print(f"smoke-user: created ephemeral user_id={user_id[:8]}…")
    print("subscription_production_smoke: PASS")
    return 0


def _get_health(base: str) -> tuple[int, dict | list | str]:
    return _request("GET", f"{base}/api/health")


if __name__ == "__main__":
    raise SystemExit(main())
