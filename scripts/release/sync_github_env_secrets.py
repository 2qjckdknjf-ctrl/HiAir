#!/usr/bin/env python3
"""Sync backend/.env.local values into GitHub environment secrets."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from dotenv import dotenv_values

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
]
DEPLOY_COMMAND = "./scripts/ops/deploy_hiair_api_cloudflare.sh"


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync GitHub environment secrets from backend/.env.local")
    parser.add_argument("--env-file", default="backend/.env.local")
    parser.add_argument("--environment", action="append", default=["staging", "production"])
    parser.add_argument("--set-deploy-command", action="store_true")
    args = parser.parse_args()

    env_path = Path(args.env_file)
    if not env_path.exists():
        print(f"Missing {env_path}", file=sys.stderr)
        return 1

    vals = dict(dotenv_values(env_path))
    if not vals.get("SUPABASE_ANON_KEY") and vals.get("SUPABASE_PUBLISHABLE_KEY"):
        vals["SUPABASE_ANON_KEY"] = vals["SUPABASE_PUBLISHABLE_KEY"]

    for env_name in args.environment:
        print(f"\n== {env_name} ==")
        for key in DEFAULT_KEYS:
            value = (vals.get(key) or "").strip()
            if not value:
                print(f"skip {key}: empty")
                continue
            subprocess.run(
                ["gh", "secret", "set", key, "--env", env_name, "--body", value, "-R", REPO],
                check=True,
                stdout=subprocess.DEVNULL,
            )
            print(f"set {key}: OK")
        if args.set_deploy_command:
            subprocess.run(
                ["gh", "secret", "set", "HIAIR_DEPLOY_COMMAND", "--env", env_name, "--body", DEPLOY_COMMAND, "-R", REPO],
                check=True,
                stdout=subprocess.DEVNULL,
            )
            print("set HIAIR_DEPLOY_COMMAND: OK")

    print("\nDone.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
