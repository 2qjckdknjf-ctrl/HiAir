#!/usr/bin/env python3
"""Enable Google OAuth on hiair-prod via Supabase Management API.

Requires:
  1) Supabase account PAT (NOT service_role JWT) as SUPABASE_ACCESS_TOKEN
     in ~/.config/hiair/supabase-credentials.env
  2) Google Cloud OAuth Web client credentials:
     - GOOGLE_OAUTH_CLIENT_ID
     - GOOGLE_OAUTH_CLIENT_SECRET
     (env vars, or lines in ~/.config/hiair/google-oauth.env)

Google Cloud Console (project e.g. hiair-wellness-prod):
  APIs & Services → Credentials → Create OAuth client ID → Web application
  Authorized redirect URI:
    https://qhxesaemlhzwbunpqjoo.supabase.co/auth/v1/callback

Usage:
  python3 scripts/ops/configure_supabase_google_provider.py
  python3 scripts/ops/configure_supabase_google_provider.py --dry-run
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

PROJECT_REF = os.getenv("SUPABASE_PROJECT_REF", "qhxesaemlhzwbunpqjoo")
MANAGEMENT_API = "https://api.supabase.com/v1"
ROOT = Path(__file__).resolve().parents[2]
GOOGLE_ENV = Path.home() / ".config" / "hiair" / "google-oauth.env"
SUPABASE_CREDS = Path.home() / ".config" / "hiair" / "supabase-credentials.env"


def _load_env_file(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        out[key.strip()] = value.strip().strip('"').strip("'")
    return out


def _load_pat() -> str:
    token = os.getenv("SUPABASE_ACCESS_TOKEN", "").strip()
    if token and not token.startswith("eyJ"):
        return token
    for key, value in _load_env_file(SUPABASE_CREDS).items():
        if key == "SUPABASE_ACCESS_TOKEN" and value and not value.startswith("eyJ"):
            return value
    return ""


def _load_google_creds() -> tuple[str, str]:
    client_id = os.getenv("GOOGLE_OAUTH_CLIENT_ID", "").strip()
    client_secret = os.getenv("GOOGLE_OAUTH_CLIENT_SECRET", "").strip()
    file_vals = _load_env_file(GOOGLE_ENV)
    if not client_id:
        client_id = file_vals.get("GOOGLE_OAUTH_CLIENT_ID", "").strip()
    if not client_secret:
        client_secret = file_vals.get("GOOGLE_OAUTH_CLIENT_SECRET", "").strip()
    return client_id, client_secret


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
    parser = argparse.ArgumentParser(description="Configure Supabase Google auth provider")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    client_id, client_secret = _load_google_creds()
    if not client_id or not client_secret:
        print(
            "error: missing GOOGLE_OAUTH_CLIENT_ID / GOOGLE_OAUTH_CLIENT_SECRET.\n"
            f"  Create a Web OAuth client and store them in {GOOGLE_ENV} or env.\n"
            "  Redirect URI: "
            f"https://{PROJECT_REF}.supabase.co/auth/v1/callback",
            file=sys.stderr,
        )
        return 1

    body = {
        "external_google_enabled": True,
        "external_google_client_id": client_id,
        "external_google_secret": client_secret,
        "site_url": "https://hiair.io",
        "uri_allow_list": (
            "hiair://auth/callback,"
            "com.hiair://auth/callback,"
            f"https://{PROJECT_REF}.supabase.co/auth/v1/callback,"
            "https://hiair.io/**"
        ),
    }

    if args.dry_run:
        print("Dry run. Would PATCH auth config:")
        print(f"- external_google_enabled: true")
        print(f"- external_google_client_id: {client_id[:12]}… (len={len(client_id)})")
        print(f"- external_google_secret: (len={len(client_secret)})")
        return 0

    pat = _load_pat()
    if not pat:
        print(
            "error: add Supabase account PAT as SUPABASE_ACCESS_TOKEN "
            f"in {SUPABASE_CREDS} (service_role JWT cannot call Management API).",
            file=sys.stderr,
        )
        print(
            f"Dashboard: https://supabase.com/dashboard/project/{PROJECT_REF}/auth/providers"
        )
        return 1

    result = _patch_auth(pat, body)
    print(f"Supabase Google provider enabled={result.get('external_google_enabled', True)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
