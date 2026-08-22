#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
API_DIR="${ROOT_DIR}/infra/cloudflare/hiair-api"
ENV_FILE="${HIAIR_API_ENV_FILE:-${ROOT_DIR}/backend/.env.local}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: env file not found: ${ENV_FILE}" >&2
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "ERROR: docker buildx is required for Cloudflare Containers deploy." >&2
  echo "Install: brew install docker-buildx && mkdir -p ~/.docker/cli-plugins && ln -sf \"\$(brew --prefix docker-buildx)/bin/docker-buildx\" ~/.docker/cli-plugins/docker-buildx" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker must be running for Cloudflare Containers deploy." >&2
  echo "Install/start Docker Desktop or run: brew install colima docker && colima start" >&2
  exit 1
fi

echo "[api] verifying Cloudflare API token"
python3 "${ROOT_DIR}/scripts/ops/verify_cloudflare_deploy_token.py" || {
  echo "ERROR: Cloudflare deploy token preflight failed." >&2
  echo "Rotate GitHub production secret CLOUDFLARE_API_TOKEN (Custom API Token)." >&2
  echo "See docs/_operator/cloudflare-deploy-token-runbook.md" >&2
  exit 1
}

echo "[api] installing worker dependencies"
(
  cd "${API_DIR}"
  npm install --no-fund --no-audit
)

echo "[api] syncing wrangler secrets from ${ENV_FILE}"
TMP_SECRETS="$(mktemp)"
python3 <<PY >"${TMP_SECRETS}"
import os
import sys
from pathlib import Path

allowed = {
    "APP_ENV",
    "DATABASE_URL",
    "DIRECT_DATABASE_URL",
    "JWT_SECRET",
    "JWT_ALGORITHM",
    "HIAIR_AUTH_PROVIDER",
    "HIAIR_AUTH_LEGACY_ENABLED",
    "HIAIR_IOS_URL_SCHEME",
    "HIAIR_ANDROID_URL_SCHEME",
    "HIAIR_AUTH_REDIRECT_URI",
    "HIAIR_AUTH_EMAIL_BRIDGE_ENABLED",
    "ALLOW_LEGACY_USER_HEADER_AUTH",
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "SUPABASE_SERVICE_ROLE_KEY",
    "SUPABASE_JWT_SECRET",
    "OPENAI_API_KEY",
    "OPENAI_MODEL",
    "OPENAI_BASE_URL",
    "OPENAI_PROMPT_VERSION",
    "OPENAI_RATE_LIMIT_PER_MINUTE",
    "OPENAI_HTTP_TIMEOUT_SECONDS",
    "OPENAI_MAX_TOKENS",
    "NOTIFICATION_ADMIN_TOKEN",
    "NOTIFICATIONS_PROVIDER_MODE",
    "SUBSCRIPTION_PROVIDER",
    "SUBSCRIPTION_WEBHOOK_SECRET",
  "APPLE_STORE_VERIFIER_MODE",
  "GOOGLE_PLAY_VERIFIER_MODE",
  "APPLE_BUNDLE_ID",
  "APPLE_STORE_ENVIRONMENT",
  "APPLE_APP_APPLE_ID",
  "GOOGLE_PLAY_PACKAGE_NAME",
  "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
  "APPLE_TEAM_ID",
  "APPLE_SIGN_IN_KEY_ID",
  "APPLE_SERVICES_ID",
  "APPLE_SIGN_IN_P8_CONTENT",
  "APPLE_SIGN_IN_P8_PATH",
  "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK",
  "DEPLOY_GIT_SHA",
  "WEATHER_API_PROVIDER",
  "WEATHER_API_KEY",
  "AQI_API_PROVIDER",
  "AQI_API_KEY",
};
values = {}
for raw in Path("${ENV_FILE}").read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    key = key.strip()
    if key in allowed and value.strip():
        values[key] = value.strip()
values.setdefault("APP_ENV", "production")
values.setdefault("APPLE_BUNDLE_ID", "com.hiair.app")
values.setdefault("GOOGLE_PLAY_PACKAGE_NAME", "com.hiair")
# Never silently default production Apple verification to stub.
app_env = values.get("APP_ENV", "production").strip().lower()
if app_env in ("production", "prod", "staging"):
    apple_mode = values.get("APPLE_STORE_VERIFIER_MODE", "").strip().lower()
    apple_store_env = values.get("APPLE_STORE_ENVIRONMENT", "").strip().lower()
    apple_app_id = values.get("APPLE_APP_APPLE_ID", "").strip()
    google_mode = values.get("GOOGLE_PLAY_VERIFIER_MODE", "").strip().lower()
    google_sa = values.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "").strip()
    auth_provider = values.get("HIAIR_AUTH_PROVIDER", "").strip().lower()
    subscription_provider = values.get("SUBSCRIPTION_PROVIDER", "").strip().lower()
    if apple_mode != "live":
        raise SystemExit("ERROR: production deploy requires APPLE_STORE_VERIFIER_MODE=live")
    if apple_store_env not in ("production", "prod"):
        raise SystemExit("ERROR: production deploy requires APPLE_STORE_ENVIRONMENT=production")
    if not apple_app_id.isdigit():
        raise SystemExit("ERROR: production deploy requires numeric APPLE_APP_APPLE_ID")
    if google_mode not in ("live", "disabled"):
        raise SystemExit(
            "ERROR: production deploy requires GOOGLE_PLAY_VERIFIER_MODE=live or disabled"
        )
    if google_mode == "live" and not google_sa:
        raise SystemExit(
            "ERROR: production deploy requires GOOGLE_PLAY_SERVICE_ACCOUNT_JSON "
            "when GOOGLE_PLAY_VERIFIER_MODE=live"
        )
    if google_mode == "disabled":
        print(
            "WARNING: GOOGLE_PLAY_VERIFIER_MODE=disabled — Android billing unavailable "
            "(not STORE SANDBOX READY)",
            file=sys.stderr,
        )
    if auth_provider and auth_provider != "supabase":
        raise SystemExit("ERROR: production deploy requires HIAIR_AUTH_PROVIDER=supabase")
    if not auth_provider:
        values["HIAIR_AUTH_PROVIDER"] = "supabase"
    if not subscription_provider or subscription_provider == "stub":
        raise SystemExit("ERROR: production deploy requires SUBSCRIPTION_PROVIDER != stub")
    apple_team = values.get("APPLE_TEAM_ID", "").strip()
    apple_key_id = values.get("APPLE_SIGN_IN_KEY_ID", "").strip()
    apple_services_id = values.get("APPLE_SERVICES_ID", "").strip()
    apple_p8_content = values.get("APPLE_SIGN_IN_P8_CONTENT", "").strip()
    apple_p8_path = values.get("APPLE_SIGN_IN_P8_PATH", "").strip()
    if not apple_team or not apple_key_id or not apple_services_id:
        raise SystemExit(
            "ERROR: production deploy requires APPLE_TEAM_ID, APPLE_SIGN_IN_KEY_ID, "
            "and APPLE_SERVICES_ID for Sign in with Apple account deletion"
        )
    if not apple_p8_content and not apple_p8_path:
        raise SystemExit(
            "ERROR: production deploy requires APPLE_SIGN_IN_P8_CONTENT "
            "(preferred) or APPLE_SIGN_IN_P8_PATH"
        )
    # Fail-closed: never serve synthetic sample/mock environment data in protected deploys.
    values["ENVIRONMENT_ALLOW_SAMPLE_FALLBACK"] = "false"
else:
    values.setdefault("APPLE_STORE_VERIFIER_MODE", "stub")
    values.setdefault("GOOGLE_PLAY_VERIFIER_MODE", "stub")
    values.setdefault("APPLE_STORE_ENVIRONMENT", "sandbox")
values.setdefault("GOOGLE_PLAY_VERIFIER_MODE", values.get("GOOGLE_PLAY_VERIFIER_MODE", "stub"))
values.setdefault("HIAIR_AUTH_PROVIDER", values.get("HIAIR_AUTH_PROVIDER", "supabase"))
values["HIAIR_AUTH_EMAIL_BRIDGE_ENABLED"] = "true"
deploy_sha = os.environ.get("GITHUB_SHA", "").strip() or os.environ.get("DEPLOY_GIT_SHA", "").strip()
if deploy_sha:
    values["DEPLOY_GIT_SHA"] = deploy_sha
required = ("DATABASE_URL", "JWT_SECRET", "DEPLOY_GIT_SHA", "SUPABASE_URL")
missing = [key for key in required if not values.get(key)]
if missing:
    raise SystemExit(f"ERROR: Cloudflare secrets missing required keys: {', '.join(missing)}")
if len(values) < 12:
    raise SystemExit(
        f"ERROR: Cloudflare secrets under-populated ({len(values)} keys); "
        "refusing partial secret sync that would leave production on stale container env"
    )
# Keys only on stderr — never print secret values to logs.
print("Syncing Cloudflare secret keys:", file=sys.stderr)
for key in sorted(values):
    print(f"  - {key}", file=sys.stderr)
print(f"Wrote {len(values)} secrets (values redacted from logs)", file=sys.stderr)
for key, value in sorted(values.items()):
    print(f"{key}={value}")
PY

(
  cd "${API_DIR}"
  npx --yes wrangler@4 secret bulk "${TMP_SECRETS}"
)
rm -f "${TMP_SECRETS}"

echo "[api] deploying Cloudflare Container worker to api.hiair.io"
(
  cd "${API_DIR}"
  npx --yes wrangler@4 deploy
)

echo "[api] deployed; first cold start may take a few minutes"
