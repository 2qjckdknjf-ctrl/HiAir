#!/usr/bin/env python3
"""Validate CLOUDFLARE_API_TOKEN before Workers/Containers deploy."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request


def _get(url: str, token: str) -> tuple[int, dict]:
    req = urllib.request.Request(
        url,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(body)
        except json.JSONDecodeError:
            payload = {"raw": body[:500]}
        return exc.code, payload


def _request_status(url: str, token: str) -> int:
    req = urllib.request.Request(
        url,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            resp.read()
            return resp.status
    except urllib.error.HTTPError as exc:
        return exc.code


def main() -> int:
    token = os.getenv("CLOUDFLARE_API_TOKEN", "").strip()
    account_id = os.getenv("CLOUDFLARE_ACCOUNT_ID", "").strip()

    if not token:
        print("cloudflare-token: FAIL missing CLOUDFLARE_API_TOKEN")
        print("action: set GitHub production secret CLOUDFLARE_API_TOKEN (Custom API Token, not expired OAuth)")
        return 1

    status, verify = _get("https://api.cloudflare.com/client/v4/user/tokens/verify", token)
    token_ok = status == 200 and verify.get("success") and (verify.get("result") or {}).get("status") == "active"
    if token_ok:
        print("cloudflare-token: OK verify active (custom API token)")
    else:
        # Wrangler OAuth bearer tokens fail /user/tokens/verify (code 1000) but still deploy.
        status, accounts_probe = _get("https://api.cloudflare.com/client/v4/accounts", token)
        if status != 200 or not accounts_probe.get("success"):
            print(f"cloudflare-token: FAIL verify status={status}")
            errors = verify.get("errors") or accounts_probe.get("errors") or []
            if errors:
                print(f"error: {errors[0].get('message', errors[0])} code={errors[0].get('code')}")
            print("action: rotate GitHub production CLOUDFLARE_API_TOKEN (Custom API Token preferred)")
            return 1
        print("cloudflare-token: OK oauth functional check (prefer Custom API Token for CI stability)")

    if account_id:
        status, accounts = _get("https://api.cloudflare.com/client/v4/accounts", token)
        if status != 200 or not accounts.get("success"):
            print(f"cloudflare-account: FAIL list accounts status={status}")
            errors = accounts.get("errors") or []
            if errors:
                print(f"error: {errors[0].get('message', errors[0])} code={errors[0].get('code')}")
            print("action: token needs Account read permission")
            return 1
        ids = {item.get("id") for item in accounts.get("result") or []}
        if account_id not in ids:
            print(f"cloudflare-account: FAIL CLOUDFLARE_ACCOUNT_ID not accessible: {account_id[:8]}…")
            return 1
        print(f"cloudflare-account: OK account accessible ({account_id[:8]}…)")

        worker_url = f"https://api.cloudflare.com/client/v4/accounts/{account_id}/workers/scripts/hiair-api"
        status = _request_status(worker_url, token)
        if status == 403:
            print("cloudflare-worker: FAIL cannot read workers script hiair-api (permission)")
            print("action: grant Workers Scripts Edit on Custom API Token")
            return 1
        if status not in (200, 404):
            print(f"cloudflare-worker: FAIL unexpected status={status}")
            return 1
        print("cloudflare-worker: OK script endpoint reachable")

    print("cloudflare-deploy-preflight: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
