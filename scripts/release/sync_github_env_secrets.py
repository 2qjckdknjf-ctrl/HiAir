#!/usr/bin/env python3
"""Sync selected env keys into GitHub environment secrets via authenticated `gh` CLI.

Never prints secret values. Never passes GitHub tokens through CLI arguments.
Does not invent production modes from a local/stub .env.local — callers must
provide an explicit --env-file whose modes are already production-safe.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from dotenv import dotenv_values

REPO = "2qjckdknjf-ctrl/HiAir"
DEPLOY_COMMAND = "./scripts/ops/deploy_hiair_api_cloudflare.sh"

# Durable production contract keys that must remain syncable (names only in logs).
PRODUCTION_CONTRACT_KEYS = (
    "HIAIR_AUTH_PROVIDER",
    "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK",
    "APPLE_STORE_VERIFIER_MODE",
    "APPLE_STORE_ENVIRONMENT",
    "APPLE_APP_APPLE_ID",
    "APPLE_BUNDLE_ID",
    "GOOGLE_PLAY_VERIFIER_MODE",
    "GOOGLE_PLAY_PACKAGE_NAME",
    "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
)

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
    *PRODUCTION_CONTRACT_KEYS,
]


def _set_env_secret(env_name: str, secret_name: str, secret_value: str) -> None:
    """Write one environment secret using the local `gh` authenticated session."""
    proc = subprocess.run(
        [
            "gh",
            "secret",
            "set",
            secret_name,
            "--env",
            env_name,
            "--repo",
            REPO,
        ],
        input=secret_value,
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "").strip()
        raise RuntimeError(f"gh secret set failed for {secret_name}: {err or 'unknown error'}")


def _validate_production_modes(vals: dict[str, str | None], environment: str) -> None:
    if environment != "production":
        return
    apple_mode = (vals.get("APPLE_STORE_VERIFIER_MODE") or "").strip().lower()
    apple_env = (vals.get("APPLE_STORE_ENVIRONMENT") or "").strip().lower()
    google_mode = (vals.get("GOOGLE_PLAY_VERIFIER_MODE") or "").strip().lower()
    auth = (vals.get("HIAIR_AUTH_PROVIDER") or "").strip().lower()
    sub = (vals.get("SUBSCRIPTION_PROVIDER") or "").strip().lower()
    sample = (vals.get("ENVIRONMENT_ALLOW_SAMPLE_FALLBACK") or "").strip().lower()
    if apple_mode and apple_mode != "live":
        raise SystemExit("production sync refused: APPLE_STORE_VERIFIER_MODE must be live")
    if apple_env and apple_env not in ("production", "prod"):
        raise SystemExit("production sync refused: APPLE_STORE_ENVIRONMENT must be production")
    if google_mode and google_mode not in ("live", "disabled"):
        raise SystemExit("production sync refused: GOOGLE_PLAY_VERIFIER_MODE must be live or disabled")
    if google_mode == "stub":
        raise SystemExit("production sync refused: GOOGLE_PLAY_VERIFIER_MODE=stub forbidden")
    if auth and auth != "supabase":
        raise SystemExit("production sync refused: HIAIR_AUTH_PROVIDER must be supabase")
    if sub == "stub":
        raise SystemExit("production sync refused: SUBSCRIPTION_PROVIDER=stub forbidden")
    if sample == "true":
        raise SystemExit("production sync refused: ENVIRONMENT_ALLOW_SAMPLE_FALLBACK=true forbidden")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Sync GitHub environment secrets from an explicit env file (values never logged)."
    )
    parser.add_argument(
        "--env-file",
        required=True,
        help="Path to env file. For production, use a dedicated production-safe file — not local stub .env.local.",
    )
    parser.add_argument("--environment", action="append", default=[])
    parser.add_argument("--set-deploy-command", action="store_true")
    parser.add_argument(
        "--keys",
        nargs="*",
        default=None,
        help="Optional subset of keys to sync (default: full DEFAULT_KEYS contract).",
    )
    args = parser.parse_args()
    environments = args.environment or ["staging", "production"]

    env_path = Path(args.env_file)
    if not env_path.is_absolute():
        env_path = Path(__file__).resolve().parents[2] / env_path
    if not env_path.exists():
        print(f"Missing {env_path}", file=sys.stderr)
        return 1

    vals = dict(dotenv_values(env_path))
    if not vals.get("SUPABASE_ANON_KEY") and vals.get("SUPABASE_PUBLISHABLE_KEY"):
        vals["SUPABASE_ANON_KEY"] = vals["SUPABASE_PUBLISHABLE_KEY"]

    keys = list(args.keys) if args.keys else list(DEFAULT_KEYS)
    for env_name in environments:
        print(f"\n== {env_name} ==")
        _validate_production_modes(vals, env_name)
        for key in keys:
            value = (vals.get(key) or "").strip()
            if not value:
                print(f"skip {key}")
                continue
            _set_env_secret(env_name, key, value)
            print(f"set {key}")
        if args.set_deploy_command:
            _set_env_secret(env_name, "HIAIR_DEPLOY_COMMAND", DEPLOY_COMMAND)
            print("set HIAIR_DEPLOY_COMMAND")

    print("\nDone.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
