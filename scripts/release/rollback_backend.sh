#!/usr/bin/env bash
set -euo pipefail

TARGET_RELEASE="${1:-previous}"
BACKEND_ROOT="$(cd "$(dirname "$0")/../../backend" && pwd)"
if [[ -x "${BACKEND_ROOT}/.venv/bin/python" ]]; then
  PYTHON_BIN="${PYTHON_BIN:-${BACKEND_ROOT}/.venv/bin/python}"
else
  PYTHON_BIN="${PYTHON_BIN:-python3}"
fi

if [[ -z "${HIAIR_ROLLBACK_COMMAND:-}" ]]; then
  echo "[rollback] HIAIR_ROLLBACK_COMMAND is required"
  exit 1
fi

echo "[rollback] target=${TARGET_RELEASE}"
bash -lc "${HIAIR_ROLLBACK_COMMAND}"

echo "[rollback] running post-rollback smoke"
"${PYTHON_BIN}" backend/scripts/smoke_db_flow.py
