#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILED=0

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

check_android_release_config() {
  ROOT_DIR_ENV="${ROOT_DIR}" python3 - <<'PY'
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
  ROOT_DIR_ENV="${ROOT_DIR}" python3 - <<'PY'
import os
from pathlib import Path
root = Path(os.environ["ROOT_DIR_ENV"])
text = (root / "mobile/ios/HiAir/Networking/APIClient.swift").read_text(encoding="utf-8")
assert '#else' in text
assert 'let defaultBaseURL = "https://api.hiair.app"' in text
assert 'validatedBaseURL' in text
PY
}

check_repo_secret_baseline() {
  ROOT_DIR_ENV="${ROOT_DIR}" python3 - <<'PY'
import os
import re
from pathlib import Path

root = Path(os.environ["ROOT_DIR_ENV"])
deny = re.compile(
    r'AKIA[0-9A-Z]{16}|-----BEGIN (?:RSA|EC|OPENSSH|PRIVATE) KEY-----\n|ghp_[A-Za-z0-9]{20,}|AIza[0-9A-Za-z\-_]{20,}'
)
skip_dirs = {".git", "docs", ".venv", "mobile/android/.gradle", "mobile/android/app/build", "mobile/ios/build"}
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

echo "HiAir final gate root: ${ROOT_DIR}"

run_step "Android release config verification" check_android_release_config
run_step "iOS release config verification" check_ios_release_config
run_step "Repository secret baseline scan" check_repo_secret_baseline

if command -v python3 >/dev/null 2>&1 && [[ -x "${ROOT_DIR}/.venv/bin/python" ]]; then
  run_step "Backend full test suite" bash -lc "cd '${ROOT_DIR}/backend' && ../.venv/bin/python -m pytest tests -q"
  run_step "Backend strict env check" bash -lc "cd '${ROOT_DIR}/backend' && ../.venv/bin/python scripts/check_env_security.py --strict --env-file .env.local"
  run_step "Backend gate (skip-db)" bash -lc "cd '${ROOT_DIR}/backend' && ./run_gate.sh --skip-db"
else
  echo "[WARN] Python/.venv unavailable; backend checks skipped."
fi

if command -v xcodebuild >/dev/null 2>&1; then
  run_step "iOS Debug simulator build" bash -lc "cd '${ROOT_DIR}/mobile/ios' && xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build"
  run_step "iOS Release simulator build no-sign" bash -lc "cd '${ROOT_DIR}/mobile/ios' && xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO"
else
  echo "[WARN] xcodebuild unavailable; iOS checks skipped."
fi

if [[ -x "${ROOT_DIR}/mobile/android/gradlew" ]]; then
  run_step "Android unit tests + debug/release assemble + lint" bash -lc "cd '${ROOT_DIR}/mobile/android' && ./gradlew test assembleDebug assembleRelease lintDebug --no-daemon"
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
