#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-staging}"
BACKEND_ROOT="$(cd "$(dirname "$0")/../../backend" && pwd)"
if [[ -x "${BACKEND_ROOT}/.venv/bin/python" ]]; then
  PYTHON_BIN="${PYTHON_BIN:-${BACKEND_ROOT}/.venv/bin/python}"
else
  PYTHON_BIN="${PYTHON_BIN:-python3}"
fi

if [[ "${DATABASE_URL:-}" == *"localhost"* || "${DATABASE_URL:-}" == *"127.0.0.1"* ]]; then
  export HIAIR_SMOKE_LEGACY_AUTH="${HIAIR_SMOKE_LEGACY_AUTH:-true}"
fi

export RETENTION_NOTIFICATION_DELIVERY_ATTEMPTS_DAYS="${RETENTION_NOTIFICATION_DELIVERY_ATTEMPTS_DAYS:-90}"
export RETENTION_NOTIFICATION_EVENTS_DAYS="${RETENTION_NOTIFICATION_EVENTS_DAYS:-180}"
export RETENTION_SUBSCRIPTION_WEBHOOK_EVENTS_DAYS="${RETENTION_SUBSCRIPTION_WEBHOOK_EVENTS_DAYS:-180}"
export RETENTION_SECRET_ROTATION_EVENTS_DAYS="${RETENTION_SECRET_ROTATION_EVENTS_DAYS:-365}"

export APP_ENV="${APP_ENV:-${ENVIRONMENT}}"

echo "[deploy] environment=${ENVIRONMENT} app_env=${APP_ENV}"
"${PYTHON_BIN}" backend/scripts/check_env_security.py --strict
"${PYTHON_BIN}" backend/scripts/init_db.py

# Local DB smoke is intentionally stub/mock-capable. Protected APP_ENV forbids those
# paths, so isolate smoke into a child env while keeping the strict production gate above.
echo "[deploy] DB smoke (isolated stub-capable child env)"
(
  export APP_ENV=development
  export HIAIR_ALLOW_INSECURE_LOCAL_DEV=false
  export APPLE_STORE_VERIFIER_MODE=stub
  export GOOGLE_PLAY_VERIFIER_MODE=stub
  export SUBSCRIPTION_PROVIDER=stub
  export ENVIRONMENT_ALLOW_SAMPLE_FALLBACK=true
  "${PYTHON_BIN}" backend/scripts/smoke_db_flow.py
)

echo "[deploy] AI connection observability"
"${PYTHON_BIN}" backend/scripts/check_ai_connection.py --skip-if-unconfigured

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  echo "[deploy] live LLM persistence gate"
  if "${PYTHON_BIN}" backend/scripts/seed_ai_live_probe.py; then
    "${PYTHON_BIN}" backend/scripts/check_ai_connection.py --require-live
  else
    echo "[deploy] seed_ai_live_probe skipped (no profiles); live LLM already verified in smoke when key is set"
  fi
fi

if [[ -n "${HIAIR_DEPLOY_COMMAND:-}" ]]; then
  echo "[deploy] executing custom deploy command"
  bash -lc "${HIAIR_DEPLOY_COMMAND}"
else
  echo "[deploy] HIAIR_DEPLOY_COMMAND is not set; running in verification-only mode"
fi
