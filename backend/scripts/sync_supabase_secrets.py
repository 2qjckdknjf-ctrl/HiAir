#!/usr/bin/env python3
"""Pull Supabase project secrets into backend/.env.local via Management API.

Requires a Personal Access Token (PAT) with access to the HiAir org:
  https://supabase.com/dashboard/account/tokens

Set token in one of:
  - environment variable SUPABASE_ACCESS_TOKEN
  - ~/.config/hiair/supabase-credentials.env  (SUPABASE_ACCESS_TOKEN=...)

Usage:
  python3 backend/scripts/sync_supabase_secrets.py
  python3 backend/scripts/sync_supabase_secrets.py --project-ref qhxesaemlhzwbunpqjoo
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

DEFAULT_PROJECT_REF = "qhxesaemlhzwbunpqjoo"
DEFAULT_REGION_POOLER_HOST = "aws-1-eu-central-1.pooler.supabase.com"
DEFAULT_POOLER_PORT = 5432
MANAGEMENT_API = "https://api.supabase.com/v1"


def _load_access_token() -> str:
    token = os.getenv("SUPABASE_ACCESS_TOKEN", "").strip()
    if token:
        return token
    creds = Path.home() / ".config" / "hiair" / "supabase-credentials.env"
    if creds.exists():
        for line in creds.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("SUPABASE_ACCESS_TOKEN="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    return ""


def _request(method: str, path: str, token: str, body: dict | None = None) -> object:
    url = f"{MANAGEMENT_API}{path}"
    cmd = [
        "/usr/bin/curl",
        "-sS",
        "-X",
        method,
        url,
        "-H",
        f"Authorization: Bearer {token}",
        "-H",
        "Content-Type: application/json",
        "-w",
        "\n%{http_code}",
    ]
    if body is not None:
        cmd.extend(["-d", json.dumps(body)])
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        raise RuntimeError(f"{method} {path} curl failed: {proc.stderr.strip()}")
    raw = proc.stdout.rsplit("\n", 1)
    if len(raw) != 2:
        raise RuntimeError(f"{method} {path} unexpected curl output")
    payload, status = raw[0], raw[1].strip()
    if not status.startswith("2"):
        raise RuntimeError(f"{method} {path} failed ({status}): {payload}")
    return json.loads(payload) if payload else {}


def _pick_key(keys: list[dict], *types: str) -> str:
    for key_type in types:
        for item in keys:
            if item.get("type") == key_type or item.get("name") == key_type:
                value = item.get("api_key") or item.get("key") or ""
                if value and not item.get("disabled"):
                    return value
    return ""


def _parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def _write_env_file(path: Path, values: dict[str, str]) -> None:
    lines: list[str] = []
    if path.exists():
        for raw in path.read_text(encoding="utf-8").splitlines():
            if raw.strip().startswith("#") or "=" not in raw:
                lines.append(raw)
                continue
            key = raw.split("=", 1)[0].strip()
            if key in values:
                lines.append(f"{key}={values.pop(key)}")
            else:
                lines.append(raw)
    for key, value in values.items():
        lines.append(f"{key}={value}")
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync Supabase secrets into backend/.env.local")
    parser.add_argument("--project-ref", default=DEFAULT_PROJECT_REF)
    parser.add_argument(
        "--env-file",
        default=str(Path(__file__).resolve().parents[1] / ".env.local"),
    )
    parser.add_argument("--pooler-host", default=DEFAULT_REGION_POOLER_HOST)
    args = parser.parse_args()

    token = _load_access_token()
    if not token:
        print(
            "Missing SUPABASE_ACCESS_TOKEN. Create ~/.config/hiair/supabase-credentials.env "
            "or export SUPABASE_ACCESS_TOKEN (https://supabase.com/dashboard/account/tokens).",
            file=sys.stderr,
        )
        return 1

    project_ref = args.project_ref
    env_path = Path(args.env_file)

    keys_payload = _request("GET", f"/projects/{project_ref}/api-keys?reveal=true", token)
    keys = keys_payload if isinstance(keys_payload, list) else keys_payload.get("keys", [])

    legacy_payload: object = {}
    try:
        legacy_payload = _request("GET", f"/projects/{project_ref}/api-keys/legacy", token)
    except RuntimeError as exc:
        print(f"warn: legacy api-keys unavailable: {exc}", file=sys.stderr)

    legacy_keys: list[dict] = []
    if isinstance(legacy_payload, dict):
        legacy_keys = legacy_payload.get("keys", legacy_payload.get("api_keys", []))
        if not legacy_keys and legacy_payload.get("anon_key"):
            legacy_keys = [
                {"type": "anon", "api_key": legacy_payload["anon_key"]},
                {"type": "service_role", "api_key": legacy_payload.get("service_role_key", "")},
            ]
    elif isinstance(legacy_payload, list):
        legacy_keys = legacy_payload

    all_keys = list(keys) + list(legacy_keys)
    anon = _pick_key(all_keys, "anon", "legacy")
    service_role = _pick_key(all_keys, "service_role", "secret")
    publishable = _pick_key(all_keys, "publishable")

    password_payload = _request("POST", f"/projects/{project_ref}/database/password", token, {})
    db_password = ""
    if isinstance(password_payload, dict):
        db_password = password_payload.get("password") or password_payload.get("database_password") or ""

    if not db_password:
        raise RuntimeError("Management API did not return a database password.")

    encoded_password = re.sub(r"([:%@/])", lambda m: f"%{ord(m.group(1)):02X}", db_password)
    database_url = (
        f"postgresql://postgres.{project_ref}:{encoded_password}@{args.pooler_host}:{DEFAULT_POOLER_PORT}/postgres?sslmode=require"
    )
    direct_database_url = (
        f"postgresql://postgres:{encoded_password}@db.{project_ref}.supabase.co:5432/postgres?sslmode=require"
    )

    supabase_url = f"https://{project_ref}.supabase.co"
    updates = {
        "SUPABASE_URL": supabase_url,
        "SUPABASE_ANON_KEY": anon,
        "SUPABASE_SERVICE_ROLE_KEY": service_role,
        "SUPABASE_PUBLISHABLE_KEY": publishable,
        "SUPABASE_JWT_SECRET": "",
        "DATABASE_URL": database_url,
        "DIRECT_DATABASE_URL": direct_database_url,
        "HIAIR_AUTH_PROVIDER": "supabase",
    }

    existing = _parse_env_file(env_path)
    existing.update({k: v for k, v in updates.items() if v or k in {"SUPABASE_JWT_SECRET", "SUPABASE_SERVICE_ROLE_KEY"}})
    _write_env_file(env_path, existing)

    print(f"Updated {env_path}")
    print(f"- SUPABASE_URL={supabase_url}")
    print(f"- SUPABASE_ANON_KEY={'set' if anon else 'missing'}")
    print(f"- SUPABASE_SERVICE_ROLE_KEY={'set' if service_role else 'missing'}")
    print(f"- SUPABASE_PUBLISHABLE_KEY={'set' if publishable else 'missing'}")
    print("- SUPABASE_JWT_SECRET left empty (JWKS verification is used when empty)")
    print("- DATABASE_URL/DIRECT_DATABASE_URL pointed at Supabase")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
