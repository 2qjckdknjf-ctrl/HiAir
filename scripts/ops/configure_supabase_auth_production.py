#!/usr/bin/env python3
"""Patch hiair-prod Supabase Auth settings (redirect URLs + autoconfirm email).

Requires Supabase **account** Personal Access Token (not the project service_role JWT):
  https://supabase.com/dashboard/account/tokens

Store as SUPABASE_ACCESS_TOKEN in ~/.config/hiair/supabase-credentials.env
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

PROJECT_REF = os.getenv("SUPABASE_PROJECT_REF", "qhxesaemlhzwbunpqjoo")
MANAGEMENT_API = "https://api.supabase.com/v1"


def _load_pat() -> str:
    token = os.getenv("SUPABASE_ACCESS_TOKEN", "").strip()
    if token:
        return token
    creds = Path.home() / ".config/hiair" / "supabase-credentials.env"
    if creds.exists():
        for line in creds.read_text(encoding="utf-8").splitlines():
            if line.startswith("SUPABASE_ACCESS_TOKEN="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    return ""


def _patch(path: str, token: str, body: dict) -> dict:
    proc = subprocess.run(
        [
            "/usr/bin/curl",
            "-sS",
            "-X",
            "PATCH",
            f"{MANAGEMENT_API}{path}",
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
    token = _load_pat()
    if not token or token.startswith("eyJ"):
        print(
            "error: set a Supabase account PAT in SUPABASE_ACCESS_TOKEN "
            "(service_role JWT from Project Settings → API is not a PAT).",
            file=sys.stderr,
        )
        return 1

    body = {
        "uri_allow_list": "hiair://auth/callback,https://qhxesaemlhzwbunpqjoo.supabase.co/auth/v1/callback",
        "mailer_autoconfirm": True,
        "external_email_enabled": True,
    }
    result = _patch(f"/projects/{PROJECT_REF}/config/auth", token, body)
    print("Updated auth config:")
    print("- mailer_autoconfirm:", result.get("mailer_autoconfirm", body["mailer_autoconfirm"]))
    print("- uri_allow_list:", result.get("uri_allow_list", body["uri_allow_list"]))
    print("Enable Apple/Google in Dashboard → Authentication → Providers (OAuth client secrets).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
