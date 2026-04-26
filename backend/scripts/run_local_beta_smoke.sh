#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "$0")/.."

PYTHON_BIN="${PYTHON_BIN:-python3}"
ENV_FILE="${ENV_FILE:-.env.local}"
FALLBACK_ENV_FILE=".env.local.example"
EXIT_CODE=0

status() {
  printf '[%s] %s\n' "$1" "$2"
}

run_step() {
  local label="$1"
  shift
  if "$@"; then
    status DONE "$label"
  else
    local code=$?
    status FAILED "$label (exit=$code)"
    EXIT_CODE=1
  fi
}

if [ ! -f "$ENV_FILE" ]; then
  status BLOCKED_BY_ENV "$ENV_FILE is missing. Copy it with: cp backend/.env.local.example backend/.env.local"
  if [ -f "$FALLBACK_ENV_FILE" ]; then
    status DONE "Using $FALLBACK_ENV_FILE for this local check only."
    ENV_FILE="$FALLBACK_ENV_FILE"
  else
    exit 1
  fi
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if ! "$PYTHON_BIN" - <<'PY'
import os
import sys
import psycopg

try:
    with psycopg.connect(os.environ["DATABASE_URL"], connect_timeout=2):
        pass
except Exception as exc:
    print(f"Postgres unavailable: {exc}")
    sys.exit(2)
PY
then
  status BLOCKED_BY_ENV "Postgres is not reachable at DATABASE_URL=$DATABASE_URL"
  status BLOCKED_BY_ENV "Start local Postgres or run: docker compose -f backend/docker-compose.local.yml up -d postgres"
  EXIT_CODE=1
else
  status DONE "Postgres reachable"
  run_step "migrations/init" "$PYTHON_BIN" scripts/init_db.py
  run_step "smoke_db_flow" "$PYTHON_BIN" scripts/smoke_db_flow.py
  run_step "retention dry-run" "$PYTHON_BIN" scripts/retention_cleanup.py --dry-run
fi

run_step "env security strict" "$PYTHON_BIN" scripts/check_env_security.py --env-file "$ENV_FILE" --strict
run_step "historical risk validation" "$PYTHON_BIN" scripts/validate_risk_historical.py

if "$PYTHON_BIN" - <<'PY'
import httpx
import sys

try:
    response = httpx.get("http://127.0.0.1:8000/api/health", timeout=2)
    sys.exit(0 if response.status_code == 200 else 1)
except Exception:
    sys.exit(1)
PY
then
  run_step "API beta preflight" "$PYTHON_BIN" scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "${NOTIFICATION_ADMIN_TOKEN:-}"
else
  status BLOCKED_BY_ENV "API server is not running at http://127.0.0.1:8000; skipping beta_preflight.py"
  status BLOCKED_BY_ENV "Optional: cd backend && set -a && source .env.local && set +a && ../.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000"
  status BLOCKED_BY_ENV "Then rerun this script or: ../.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token \"\$NOTIFICATION_ADMIN_TOKEN\""
fi

exit "$EXIT_CODE"
