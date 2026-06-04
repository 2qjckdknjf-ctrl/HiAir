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

echo "[api] installing worker dependencies"
(
  cd "${API_DIR}"
  npm install --no-fund --no-audit
)

echo "[api] syncing wrangler secrets from ${ENV_FILE}"
TMP_SECRETS="$(mktemp)"
python3 <<PY >"${TMP_SECRETS}"
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
    "GOOGLE_PLAY_PACKAGE_NAME",
    "WEATHER_API_PROVIDER",
    "WEATHER_API_KEY",
    "AQI_API_PROVIDER",
    "AQI_API_KEY",
}
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
values.setdefault("APPLE_STORE_VERIFIER_MODE", "stub")
values.setdefault("GOOGLE_PLAY_VERIFIER_MODE", "stub")
values.setdefault("APPLE_BUNDLE_ID", "com.hiair.app")
values.setdefault("GOOGLE_PLAY_PACKAGE_NAME", "com.hiair")
values["HIAIR_AUTH_EMAIL_BRIDGE_ENABLED"] = "true"
for key in sorted(values):
    print(f"{key}={values[key]}")
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
