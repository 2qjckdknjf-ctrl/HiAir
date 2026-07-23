#!/usr/bin/env python3
"""Rotate GitHub production CLOUDFLARE_API_TOKEN from a local secret file.

Never prints the token. Expects one of:
  - env CLOUDFLARE_API_TOKEN
  - file backend/.secrets/cloudflare_api_token (single line)

Usage:
  python3 scripts/ops/rotate_cloudflare_github_token.py
  python3 scripts/ops/rotate_cloudflare_github_token.py --wait-seconds 600
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SECRET_FILE = ROOT / "backend" / ".secrets" / "cloudflare_api_token"
ACCOUNT_ID = "864f04d729c24f574a228558b40d7b82"


def _load_token() -> str:
    env = (os.getenv("CLOUDFLARE_API_TOKEN") or "").strip()
    if env:
        return env
    if SECRET_FILE.exists():
        return SECRET_FILE.read_text(encoding="utf-8").strip().splitlines()[0].strip()
    return ""


def _refresh_wrangler_oauth() -> str:
    """Recover deploy credential from local wrangler refresh_token when present."""
    proc = subprocess.run(
        [sys.executable, str(ROOT / "scripts/ops/refresh_wrangler_oauth.py"), "--write-secret-file"],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    for line in (proc.stdout or "").splitlines():
        print(line)
    if proc.returncode != 0:
        for line in (proc.stderr or "").splitlines():
            print(line)
        return ""
    return _load_token()


def _verify(token: str) -> int:
    env = os.environ.copy()
    env["CLOUDFLARE_API_TOKEN"] = token
    env["CLOUDFLARE_ACCOUNT_ID"] = ACCOUNT_ID
    return subprocess.call(
        [sys.executable, str(ROOT / "scripts/ops/verify_cloudflare_deploy_token.py")],
        env=env,
        cwd=str(ROOT),
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--wait-seconds", type=int, default=0)
    parser.add_argument("--skip-github", action="store_true")
    args = parser.parse_args()

    deadline = time.time() + max(args.wait_seconds, 0)
    token = _load_token()
    while not token and time.time() < deadline:
        print(f"waiting for token file: {SECRET_FILE}")
        time.sleep(5)
        token = _load_token()

    if not token:
        print("token_source: attempting wrangler oauth refresh")
        token = _refresh_wrangler_oauth()

    if token and _verify(token) != 0:
        print("token_source: existing token failed preflight; attempting wrangler oauth refresh")
        refreshed = _refresh_wrangler_oauth()
        if refreshed:
            token = refreshed

    if not token:
        print("FAIL: CLOUDFLARE_API_TOKEN not provided and wrangler oauth refresh unavailable")
        print(f"action: create Custom API Token, write one line to {SECRET_FILE}")
        print("alternate: wrangler login, then re-run this script")
        print("permissions: Account Read; Workers Scripts Edit; Workers Containers/Builds Edit")
        print("account: 864f04d729c24f574a228558b40d7b82")
        return 1

    print(f"token_loaded: yes len={len(token)}")
    if _verify(token) != 0:
        print("FAIL: preflight verify")
        return 1
    print("preflight: PASS")

    if args.skip_github:
        return 0

    sys.path.insert(0, str(ROOT / "scripts/release"))
    from sync_github_env_secrets import _github_token, _set_env_secret  # type: ignore

    gh = _github_token()
    # Only rotate CLOUDFLARE_API_TOKEN — do not touch other production secrets.
    _set_env_secret(gh, "production", "CLOUDFLARE_API_TOKEN", token)
    print("github_secret: set production/CLOUDFLARE_API_TOKEN OK")
    print(f"account_id_expected: {ACCOUNT_ID} (unchanged in GitHub)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
