#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILED=0
STRICT_EXTERNAL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict-external)
      STRICT_EXTERNAL=1
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [--strict-external]"
      exit 2
      ;;
  esac
done

run_step() {
  local title="$1"
  shift
  echo
  echo "==> ${title}"
  if "$@"; then
    echo "[PASS] ${title}"
  else
    echo "[FAIL] ${title}"
    FAILED=1
  fi
}

resolve_repo_python() {
  local candidate
  for candidate in \
    "${ROOT_DIR}/.venv312/bin/python" \
    "${ROOT_DIR}/backend/.venv/bin/python" \
    "${ROOT_DIR}/.venv/bin/python"; do
    if [[ -x "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

check_android_release_config() {
  ROOT_DIR_ENV="${ROOT_DIR}" "${GATE_PYTHON}" - <<'PY'
import os
from pathlib import Path
root = Path(os.environ["ROOT_DIR_ENV"])
gradle = (root / "mobile/android/app/build.gradle.kts").read_text(encoding="utf-8")
manifest = (root / "mobile/android/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
assert 'buildConfigField("String", "API_BASE_URL", "\\"https://' in gradle
assert 'manifestPlaceholders["usesCleartextTraffic"] = "false"' in gradle
assert 'android:usesCleartextTraffic="${usesCleartextTraffic}"' in manifest
PY
}

check_ios_release_config() {
  ROOT_DIR_ENV="${ROOT_DIR}" "${GATE_PYTHON}" - <<'PY'
import os
from pathlib import Path
root = Path(os.environ["ROOT_DIR_ENV"])
text = (root / "mobile/ios/HiAir/Networking/APIClient.swift").read_text(encoding="utf-8")
assert '#else' in text
assert 'let defaultBaseURL = "https://api.hiair.io"' in text
assert 'validatedBaseURL' in text
PY
}

check_repo_secret_baseline() {
  ROOT_DIR_ENV="${ROOT_DIR}" "${GATE_PYTHON}" - <<'PY'
import os
import re
from pathlib import Path

root = Path(os.environ["ROOT_DIR_ENV"])
deny = re.compile(
    r'AKIA[0-9A-Z]{16}|-----BEGIN (?:RSA|EC|OPENSSH|PRIVATE) KEY-----\n|ghp_[A-Za-z0-9]{20,}|AIza[0-9A-Za-z\-_]{20,}'
)
skip_dirs = {
    ".git",
    ".tools",
    ".venv312",
    ".coverage",
    "docs",
    ".venv",
    "backend/.secrets",
    "backend/.venv-ci-smoke",
    "mobile/android/.gradle",
    "mobile/android/app/build",
    "mobile/ios/build",
}
violations = []

for path in root.rglob("*"):
    if not path.is_file():
        continue
    rel = path.relative_to(root).as_posix()
    if any(rel == d or rel.startswith(f"{d}/") for d in skip_dirs):
        continue
    if path.stat().st_size > 2_000_000:
        continue
    try:
        content = path.read_text(encoding="utf-8")
    except Exception:
        continue
    if deny.search(content):
        violations.append(rel)

if violations:
    for item in violations:
        print(item)
    raise SystemExit(1)
PY
}

check_external_readiness() {
  local owner_plan_path="${ROOT_DIR}/docs/release/EXTERNAL_OWNER_ACTION_PLAN.md"
  if [[ ${STRICT_EXTERNAL} -eq 1 ]]; then
    "${GATE_PYTHON}" "${ROOT_DIR}/scripts/release/check_external_readiness.py" --strict --env-file "${ROOT_DIR}/backend/.env.local" --write-owner-plan "${owner_plan_path}"
    return
  fi
  "${GATE_PYTHON}" "${ROOT_DIR}/scripts/release/check_external_readiness.py" --env-file "${ROOT_DIR}/backend/.env.local" --write-owner-plan "${owner_plan_path}"
}

GATE_PYTHON="$(resolve_repo_python || true)"
if [[ -z "${GATE_PYTHON}" ]]; then
  echo "ERROR: No working repo Python found (.venv312, backend/.venv, .venv)." >&2
  exit 2
fi

echo "HiAir final gate root: ${ROOT_DIR}"
echo "HiAir final gate python: ${GATE_PYTHON}"

run_step "Android release config verification" check_android_release_config
run_step "iOS release config verification" check_ios_release_config
run_step "Repository secret baseline scan" check_repo_secret_baseline
run_step "External readiness checklist" check_external_readiness

REPO_PYTHON="${GATE_PYTHON}"
if [[ -n "${REPO_PYTHON}" ]]; then
  run_step "Backend full test suite" bash -lc "cd '${ROOT_DIR}/backend' && '${REPO_PYTHON}' -m pytest tests -q"
  run_step "Backend strict env check" bash -lc "cd '${ROOT_DIR}/backend' && '${REPO_PYTHON}' scripts/check_env_security.py --strict --env-file .env.local"
  run_step "Backend gate (skip-db)" bash -lc "cd '${ROOT_DIR}/backend' && HIAIR_GATE_PYTHON='${REPO_PYTHON}' ./run_gate.sh --skip-db"
else
  echo "[WARN] No repo Python venv found (.venv312, backend/.venv, .venv); backend checks skipped."
fi

if command -v xcodebuild >/dev/null 2>&1; then
  run_step "iOS Debug simulator build" bash -lc "cd '${ROOT_DIR}/mobile/ios' && xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO"
  run_step "iOS Release simulator build no-sign" bash -lc "cd '${ROOT_DIR}/mobile/ios' && xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO"
else
  echo "[WARN] xcodebuild unavailable; iOS checks skipped."
fi

if [[ -x "${ROOT_DIR}/mobile/android/gradlew" ]]; then
  if command -v java >/dev/null 2>&1 && java -version >/dev/null 2>&1; then
    run_step "Android unit tests + debug/release assemble + lint" bash -lc "cd '${ROOT_DIR}/mobile/android' && ./gradlew test assembleDebug assembleRelease lintDebug --no-daemon"
  else
    echo "[WARN] Java runtime unavailable; Android checks skipped (CI still validates on ubuntu-latest)."
  fi
else
  echo "[WARN] Android gradlew unavailable; Android checks skipped."
fi

echo
if [[ ${FAILED} -eq 0 ]]; then
  echo "HiAir final gate: PASS"
  exit 0
fi
echo "HiAir final gate: FAIL"
exit 1
