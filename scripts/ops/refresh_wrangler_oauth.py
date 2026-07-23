#!/usr/bin/env python3
"""Refresh local wrangler OAuth and optionally write deploy secret file.

Never prints token values. Uses wrangler public client_id + stored refresh_token.
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parents[2]
WRANGLER_CFG = Path.home() / "Library/Preferences/.wrangler/config/default.toml"
SECRET_FILE = ROOT / "backend" / ".secrets" / "cloudflare_api_token"
CLIENT_ID = "54d11594-84e4-41aa-b438-e81b8fa78ee7"
TOKEN_URL = "https://dash.cloudflare.com/oauth2/token"
ACCOUNT_ID = "864f04d729c24f574a228558b40d7b82"


def _read_cfg() -> dict[str, str]:
    if not WRANGLER_CFG.exists():
        return {}
    data: dict[str, str] = {}
    for line in WRANGLER_CFG.read_text(encoding="utf-8").splitlines():
        if "=" not in line or line.strip().startswith("#"):
            continue
        key, value = line.split("=", 1)
        data[key.strip()] = value.strip().strip('"').strip("'")
    return data


def _write_cfg(access: str, refresh: str, expires_in: int, scopes: str) -> None:
    exp = (datetime.now(timezone.utc) + timedelta(seconds=expires_in)).strftime(
        "%Y-%m-%dT%H:%M:%S.%f"
    )[:-3] + "Z"
    WRANGLER_CFG.parent.mkdir(parents=True, exist_ok=True)
    WRANGLER_CFG.write_text(
        f'oauth_token = "{access}"\n'
        f'expiration_time = "{exp}"\n'
        f'refresh_token = "{refresh}"\n'
        f'scopes = "{scopes}"\n',
        encoding="utf-8",
    )


def refresh() -> str:
    cfg = _read_cfg()
    refresh_token = cfg.get("refresh_token", "")
    scopes = cfg.get("scopes", "")
    if not refresh_token:
        raise RuntimeError(f"missing refresh_token in {WRANGLER_CFG}")

    with httpx.Client(timeout=30.0) as client:
        response = client.post(
            TOKEN_URL,
            data={
                "grant_type": "refresh_token",
                "refresh_token": refresh_token,
                "client_id": CLIENT_ID,
            },
        )
        if response.status_code != 200:
            raise RuntimeError(f"oauth refresh failed status={response.status_code}")
        payload = response.json()
        access = str(payload.get("access_token") or "")
        new_refresh = str(payload.get("refresh_token") or refresh_token)
        expires_in = int(payload.get("expires_in") or 3600)
        if not access:
            raise RuntimeError("oauth refresh missing access_token")

        accounts = client.get(
            "https://api.cloudflare.com/client/v4/accounts",
            headers={"Authorization": f"Bearer {access}"},
        )
        if accounts.status_code != 200 or not accounts.json().get("success"):
            raise RuntimeError(f"oauth access unusable accounts_status={accounts.status_code}")
        worker = client.get(
            f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/workers/scripts/hiair-api",
            headers={"Authorization": f"Bearer {access}"},
        )
        if worker.status_code not in (200, 404):
            raise RuntimeError(f"oauth access unusable worker_status={worker.status_code}")

    _write_cfg(access, new_refresh, expires_in, scopes)
    return access


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-secret-file", action="store_true")
    args = parser.parse_args()

    try:
        access = refresh()
    except Exception as exc:  # noqa: BLE001 - operator script
        print(f"FAIL: {exc}")
        return 1

    print(f"oauth_refresh: PASS access_len={len(access)}")
    if args.write_secret_file:
        SECRET_FILE.parent.mkdir(parents=True, exist_ok=True)
        SECRET_FILE.write_text(access + "\n", encoding="utf-8")
        SECRET_FILE.chmod(0o600)
        print(f"secret_file: wrote {SECRET_FILE} perms=600")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
