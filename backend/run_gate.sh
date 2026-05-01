#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -x "${SCRIPT_DIR}/.venv/bin/python" ]]; then
  PYTHON_BIN="${SCRIPT_DIR}/.venv/bin/python"
elif [[ -x "${REPO_ROOT}/.venv/bin/python" ]]; then
  PYTHON_BIN="${REPO_ROOT}/.venv/bin/python"
else
  PYTHON_BIN="python3"
fi

echo "[INFO] Using python: ${PYTHON_BIN}"
exec "${PYTHON_BIN}" "${SCRIPT_DIR}/scripts/run_backend_gate.py" "$@"
#!/usr/bin/env bash
set -euo pipefail

# Run the same checks as CI (`scripts/run_backend_gate.py`) using a project venv.
# Avoids PEP 668 failures from `python3 -m pip` / system interpreters on macOS/Homebrew.

BACKEND_ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$BACKEND_ROOT/.." && pwd)"

PY=""
if [[ -x "$BACKEND_ROOT/.venv/bin/python" ]]; then
  PY="$BACKEND_ROOT/.venv/bin/python"
elif [[ -x "$REPO_ROOT/.venv/bin/python" ]]; then
  PY="$REPO_ROOT/.venv/bin/python"
fi

if [[ -z "$PY" ]]; then
  cat <<EOF >&2
HiAir: no Python virtualenv found for the backend gate.

Create a venv and install dependencies (pick one layout):

  cd "$BACKEND_ROOT" && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt

Or a shared venv at the repository root:

  cd "$REPO_ROOT" && python3 -m venv .venv && .venv/bin/pip install -r backend/requirements.txt

On macOS with Homebrew Python, global pip fails with PEP 668 — always use a venv.
EOF
  exit 1
fi

# Examples: ./run_gate.sh | ./run_gate.sh --skip-db | ./run_gate.sh --skip-db --base-url http://127.0.0.1:8000
exec "$PY" "$BACKEND_ROOT/scripts/run_backend_gate.py" "$@"
