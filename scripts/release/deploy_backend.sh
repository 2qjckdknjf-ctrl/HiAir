#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-staging}"
BACKEND_ROOT="$(cd "$(dirname "$0")/../../backend" && pwd)"
if [[ -x "${BACKEND_ROOT}/.venv/bin/python" ]]; then
  PYTHON_BIN="${PYTHON_BIN:-${BACKEND_ROOT}/.venv/bin/python}"
else
  PYTHON_BIN="${PYTHON_BIN:-python3}"
fi

echo "[deploy] environment=${ENVIRONMENT}"
"${PYTHON_BIN}" backend/scripts/check_env_security.py --strict
"${PYTHON_BIN}" backend/scripts/init_db.py
"${PYTHON_BIN}" backend/scripts/smoke_db_flow.py

if [[ -n "${HIAIR_DEPLOY_COMMAND:-}" ]]; then
  echo "[deploy] executing custom deploy command"
  bash -lc "${HIAIR_DEPLOY_COMMAND}"
else
  echo "[deploy] HIAIR_DEPLOY_COMMAND is not set; running in verification-only mode"
fi
