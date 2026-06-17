#!/usr/bin/env python3
"""Sync backend/.env.local values into GitHub environment secrets (GitHub API)."""

from __future__ import annotations

import argparse
import base64
import json
import re
import subprocess
import sys
from pathlib import Path

from dotenv import dotenv_values
from nacl import encoding, public

REPO = "2qjckdknjf-ctrl/HiAir"
DEFAULT_KEYS = [
    "DATABASE_URL",
    "DIRECT_DATABASE_URL",
    "JWT_SECRET",
    "NOTIFICATION_ADMIN_TOKEN",
    "SUBSCRIPTION_PROVIDER",
    "SUBSCRIPTION_WEBHOOK_SECRET",
    "OPENAI_API_KEY",
    "OPENAI_MODEL",
    "OPENAI_BASE_URL",
    "OPENAI_PROMPT_VERSION",
    "OPENAI_RATE_LIMIT_PER_MINUTE",
    "OPENAI_HTTP_TIMEOUT_SECONDS",
    "OPENAI_MAX_TOKENS",
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "SUPABASE_SERVICE_ROLE_KEY",
    "SUPABASE_JWT_SECRET",
    "CLOUDFLARE_API_TOKEN",
    "CLOUDFLARE_ACCOUNT_ID",
    "WEATHER_API_PROVIDER",
    "WEATHER_API_KEY",
    "AQI_API_PROVIDER",
    "AQI_API_KEY",
    "NOTIFICATIONS_PROVIDER_MODE",
]
DEPLOY_COMMAND = "./scripts/ops/deploy_hiair_api_cloudflare.sh"


def _github_token() -> str:
    proc = subprocess.run(
        ["git", "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n",
        capture_output=True,
        text=True,
        cwd=Path(__file__).resolve().parents[2],
    )
    for line in proc.stdout.splitlines():
        if line.startswith("password="):
            return line.split("=", 1)[1]
    raise RuntimeError("GitHub token unavailable via git credential")


def _wrangler_oauth_token() -> str:
    cfg = Path.home() / "Library/Preferences/.wrangler/config/default.toml"
    if not cfg.exists():
        return ""
    match = re.search(r'oauth_token = "([^"]+)"', cfg.read_text(encoding="utf-8"))
    return match.group(1) if match else ""


def _set_env_secret(gh_token: str, env_name: str, secret_name: str, secret_value: str) -> None:
    pk_resp = subprocess.check_output(
        [
            "curl",
            "-fsS",
            "-H",
            f"Authorization: token {gh_token}",
            f"https://api.github.com/repos/{REPO}/environments/{env_name}/secrets/public-key",
        ],
        text=True,
    )
    pk = json.loads(pk_resp)
    pub = public.PublicKey(pk["key"].encode(), encoding.Base64Encoder)
    sealed = public.SealedBox(pub).encrypt(secret_value.encode())
    body = json.dumps({"encrypted_value": base64.b64encode(sealed).decode(), "key_id": pk["key_id"]})
    subprocess.run(
        [
            "curl",
            "-fsS",
            "-X",
            "PUT",
            "-H",
            f"Authorization: token {gh_token}",
            "-H",
            "Accept: application/vnd.github+json",
            "-H",
            "Content-Type: application/json",
            f"https://api.github.com/repos/{REPO}/environments/{env_name}/secrets/{secret_name}",
            "-d",
            body,
        ],
        check=True,
        stdout=subprocess.DEVNULL,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync GitHub environment secrets from backend/.env.local")
    parser.add_argument("--env-file", default="backend/.env.local")
    parser.add_argument("--environment", action="append", default=["staging", "production"])
    parser.add_argument("--set-deploy-command", action="store_true")
    parser.add_argument("--refresh-cloudflare-oauth", action="store_true")
    args = parser.parse_args()

    env_path = Path(args.env_file)
    if not env_path.is_absolute():
        env_path = Path(__file__).resolve().parents[2] / env_path
    if not env_path.exists():
        print(f"Missing {env_path}", file=sys.stderr)
        return 1

    vals = dict(dotenv_values(env_path))
    if not vals.get("SUPABASE_ANON_KEY") and vals.get("SUPABASE_PUBLISHABLE_KEY"):
        vals["SUPABASE_ANON_KEY"] = vals["SUPABASE_PUBLISHABLE_KEY"]

    if args.refresh_cloudflare_oauth or not (vals.get("CLOUDFLARE_API_TOKEN") or "").strip():
        oauth = _wrangler_oauth_token()
        if oauth:
            vals["CLOUDFLARE_API_TOKEN"] = oauth
            print("Using wrangler OAuth for CLOUDFLARE_API_TOKEN")
    if not (vals.get("CLOUDFLARE_ACCOUNT_ID") or "").strip():
        vals["CLOUDFLARE_ACCOUNT_ID"] = "864f04d729c24f574a228558b40d7b82"

    gh_token = _github_token()
    for env_name in args.environment:
        print(f"\n== {env_name} ==")
        for key in DEFAULT_KEYS:
            value = (vals.get(key) or "").strip()
            if not value:
                print(f"skip {key}: empty")
                continue
            _set_env_secret(gh_token, env_name, key, value)
            print(f"set {key}: OK")
        if args.set_deploy_command:
            _set_env_secret(gh_token, env_name, "HIAIR_DEPLOY_COMMAND", DEPLOY_COMMAND)
            print("set HIAIR_DEPLOY_COMMAND: OK")

    print("\nDone.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
