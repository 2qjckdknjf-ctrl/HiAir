#!/usr/bin/env python3
"""Create a long-lived Cloudflare Custom API Token for HiAir deploys.

Requires a bootstrap token with permission to create tokens
(User → API Tokens → Edit / "Create Additional Tokens" template).

Never prints the full new token. Writes one line to:
  backend/.secrets/cloudflare_api_token

Then optionally rotates GitHub production secret via
  scripts/ops/rotate_cloudflare_github_token.py

Usage:
  export CLOUDFLARE_BOOTSTRAP_TOKEN='...'   # Create Additional Tokens
  export CLOUDFLARE_ACCOUNT_ID='864f04d729c24f574a228558b40d7b82'
  python3 scripts/ops/create_cloudflare_custom_deploy_token.py
  python3 scripts/ops/rotate_cloudflare_github_token.py
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SECRET_FILE = ROOT / "backend" / ".secrets" / "cloudflare_api_token"
ACCOUNT_ID = os.getenv("CLOUDFLARE_ACCOUNT_ID", "864f04d729c24f574a228558b40d7b82").strip()

# Permission group IDs are stable Cloudflare identifiers.
# Workers Scripts Write + Account Settings Read cover wrangler deploy + secrets.
# Containers Edit may appear under Workers; if create fails, extend via dashboard.
PERMISSION_GROUP_IDS = [
    # Account Settings Read
    "cbf4e4b45e4b4d1aa9a1f0f7c0f9c2a1",
]


def _api(method: str, path: str, token: str, body: dict | None = None) -> dict:
    request = urllib.request.Request(
        f"https://api.cloudflare.com/client/v4{path}",
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        data=None if body is None else json.dumps(body).encode("utf-8"),
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Cloudflare API {exc.code}: {detail[:500]}") from exc


def _list_permission_groups(token: str) -> list[dict]:
    payload = _api("GET", "/user/tokens/permission_groups", token)
    if not payload.get("success"):
        raise RuntimeError(f"permission_groups failed: {payload}")
    return list(payload.get("result") or [])


def _pick_permission_ids(groups: list[dict]) -> list[dict]:
    wanted_names = {
        "Workers Scripts Write",
        "Workers Scripts Edit",
        "Workers Tail Read",
        "Account Settings Read",
        "Workers Containers Write",
        "Workers Containers Edit",
        "Workers Builds Edit",
        "Workers Builds Write",
        "Workers KV Storage Write",
        "Workers KV Storage Edit",
    }
    selected: list[dict] = []
    for group in groups:
        name = str(group.get("name") or "")
        if name in wanted_names:
            selected.append({"id": group["id"], "name": name})
    # Minimum viable: Workers Scripts Write/Edit + Account Settings Read
    names = {item["name"] for item in selected}
    if not ({"Workers Scripts Write", "Workers Scripts Edit"} & names):
        raise RuntimeError(
            "Could not find Workers Scripts Write/Edit permission group. "
            "Create the Custom Token in the dashboard using Edit Cloudflare Workers."
        )
    if "Account Settings Read" not in names:
        for group in groups:
            if group.get("name") == "Account Settings Read":
                selected.append({"id": group["id"], "name": group["name"]})
                break
    return selected


def main() -> int:
    bootstrap = (
        os.getenv("CLOUDFLARE_BOOTSTRAP_TOKEN")
        or os.getenv("CLOUDFLARE_API_TOKEN")
        or ""
    ).strip()
    if not bootstrap:
        print("FAIL: set CLOUDFLARE_BOOTSTRAP_TOKEN (Create Additional Tokens)")
        print("Dashboard: My Profile → API Tokens → Create Token → Create Additional Tokens")
        print("Then re-run this script and rotate GitHub via rotate_cloudflare_github_token.py")
        return 1
    if not ACCOUNT_ID:
        print("FAIL: CLOUDFLARE_ACCOUNT_ID required")
        return 1

    groups = _list_permission_groups(bootstrap)
    selected = _pick_permission_ids(groups)
    print("permissions:", ", ".join(sorted(item["name"] for item in selected)))

    body = {
        "name": "hiair-github-production-deploy",
        "policies": [
            {
                "effect": "allow",
                "resources": {f"com.cloudflare.api.account.{ACCOUNT_ID}": "*"},
                "permission_groups": [{"id": item["id"]} for item in selected],
            }
        ],
    }
    payload = _api("POST", "/user/tokens", bootstrap, body)
    if not payload.get("success"):
        print("FAIL: create token", payload.get("errors"))
        return 1
    result = payload.get("result") or {}
    value = str(result.get("value") or "").strip()
    token_id = str(result.get("id") or "")
    if not value:
        print("FAIL: create succeeded but token value missing")
        return 1

    SECRET_FILE.parent.mkdir(parents=True, exist_ok=True)
    SECRET_FILE.write_text(value + "\n", encoding="utf-8")
    try:
        SECRET_FILE.chmod(0o600)
    except OSError:
        pass

    print(f"token_id: {token_id}")
    print(f"token_written: {SECRET_FILE} len={len(value)}")
    print("next: python3 scripts/ops/rotate_cloudflare_github_token.py")
    print("verify: python3 scripts/ops/verify_cloudflare_deploy_token.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
