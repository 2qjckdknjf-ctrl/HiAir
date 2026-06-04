#!/usr/bin/env python3
"""Enable Sign in with Apple on hiair-prod via Supabase Management API.

Uses Apple AuthKey .p8 (Key ID 8BXW8SG2B4) to mint the OAuth client secret JWT Supabase expects.

Requires Supabase account PAT (NOT project service_role JWT):
  https://supabase.com/dashboard/account/tokens
  -> SUPABASE_ACCESS_TOKEN in ~/.config/hiair/supabase-credentials.env

Usage:
  python3 scripts/ops/configure_supabase_apple_provider.py
  python3 scripts/ops/configure_supabase_apple_provider.py --p8 backend/.secrets/AuthKey_8BXW8SG2B4.p8
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import jwt

PROJECT_REF = os.getenv("SUPABASE_PROJECT_REF", "qhxesaemlhzwbunpqjoo")
TEAM_ID = os.getenv("APPLE_TEAM_ID", "43A4KW5BKB")
KEY_ID = os.getenv("APPLE_SIGN_IN_KEY_ID", "8BXW8SG2B4")
SERVICES_ID = os.getenv("APPLE_SERVICES_ID", "com.hiair.app.auth")
BUNDLE_ID = os.getenv("APPLE_BUNDLE_ID", "com.hiair.app")
MANAGEMENT_API = "https://api.supabase.com/v1"
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_P8 = ROOT / "backend" / ".secrets" / "AuthKey_8BXW8SG2B4.p8"
SECRET_OUT = ROOT / "backend" / ".secrets" / "apple_signin_client_secret.jwt"


def _load_pat() -> str:
    token = os.getenv("SUPABASE_ACCESS_TOKEN", "").strip()
    if token and not token.startswith("eyJ"):
        return token
    creds = Path.home() / ".config" / "hiair" / "supabase-credentials.env"
    if creds.exists():
        for line in creds.read_text(encoding="utf-8").splitlines():
            if line.startswith("SUPABASE_ACCESS_TOKEN="):
                value = line.split("=", 1)[1].strip().strip('"').strip("'")
                if value and not value.startswith("eyJ"):
                    return value
    return ""


def generate_apple_client_secret(p8_path: Path) -> str:
    private_key = p8_path.read_text(encoding="utf-8")
    now = int(time.time())
    # Apple allows up to 6 months; stay under with ~150 days.
    payload = {
        "iss": TEAM_ID,
        "iat": now,
        "exp": now + 12960000,
        "aud": "https://appleid.apple.com",
        "sub": SERVICES_ID,
    }
    headers = {"kid": KEY_ID, "alg": "ES256"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers=headers)


def _patch_auth(token: str, body: dict) -> dict:
    proc = subprocess.run(
        [
            "/usr/bin/curl",
            "-sS",
            "-X",
            "PATCH",
            f"{MANAGEMENT_API}/projects/{PROJECT_REF}/config/auth",
            "-H",
            f"Authorization: Bearer {token}",
            "-H",
            "Content-Type: application/json",
            "-d",
            json.dumps(body),
            "-w",
            "\n%{http_code}",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "curl failed")
    raw = proc.stdout.rsplit("\n", 1)
    if len(raw) != 2:
        raise RuntimeError("unexpected curl output")
    payload, status = raw[0], raw[1].strip()
    if not status.startswith("2"):
        raise RuntimeError(f"PATCH failed ({status}): {payload}")
    return json.loads(payload) if payload else {}


def main() -> int:
    parser = argparse.ArgumentParser(description="Configure Supabase Apple auth provider")
    parser.add_argument("--p8", type=Path, default=DEFAULT_P8)
    parser.add_argument("--dry-run", action="store_true", help="Only generate client secret JWT file")
    args = parser.parse_args()

    if not args.p8.exists():
        print(f"error: missing Apple key: {args.p8}", file=sys.stderr)
        return 1

    client_secret = generate_apple_client_secret(args.p8)
    SECRET_OUT.parent.mkdir(parents=True, exist_ok=True)
    SECRET_OUT.write_text(client_secret + "\n", encoding="utf-8")
    SECRET_OUT.chmod(0o600)
    print(f"Wrote Apple OAuth client secret JWT -> {SECRET_OUT}")

    client_ids = f"{BUNDLE_ID},{SERVICES_ID}"
    body = {
        "external_apple_enabled": True,
        "external_apple_client_id": client_ids,
        "external_apple_secret": client_secret,
        "uri_allow_list": "hiair://auth/callback,https://qhxesaemlhzwbunpqjoo.supabase.co/auth/v1/callback",
    }

    if args.dry_run:
        print("Dry run. Dashboard paste:")
        print(f"- Client IDs: {client_ids}")
        print(f"- Secret Key: (contents of {SECRET_OUT})")
        print(f"- Key ID: {KEY_ID}  Team ID: {TEAM_ID}")
        return 0

    pat = _load_pat()
    if not pat:
        print(
            "error: add Supabase account PAT as SUPABASE_ACCESS_TOKEN "
            "(service_role JWT cannot call Management API).",
            file=sys.stderr,
        )
        print("Dashboard: https://supabase.com/dashboard/project/qhxesaemlhzwbunpqjoo/auth/providers")
        print(f"Paste Client IDs: {client_ids}")
        print(f"Paste Secret Key from: {SECRET_OUT}")
        return 1

    result = _patch_auth(pat, body)
    enabled = result.get("external_apple_enabled", True)
    print(f"Supabase Apple provider enabled={enabled}")
    print(f"Client IDs: {result.get('external_apple_client_id', client_ids)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
