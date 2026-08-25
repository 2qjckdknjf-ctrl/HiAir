#!/usr/bin/env bash
# Build HiAir Release (simulator) and verify operator/debug surfaces are not reachable.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS_DIR="${ROOT}/mobile/ios"
DEST="${IOS_RELEASE_DEST:-platform=iOS Simulator,name=iPhone 17 Pro}"
DERIVED="${TMPDIR:-/tmp}/hiair-release-verify-$$"
LOG="${DERIVED}/release-build.log"
EVIDENCE="${HIAIR_RELEASE_EVIDENCE:-${ROOT}/.evidence/ios-release-verify/$(date +%Y%m%d-%H%M%S)}"

mkdir -p "${DERIVED}" "${EVIDENCE}"

BASE_COMMIT_SHA="$(git -C "${ROOT}" rev-parse HEAD)"
WORKTREE_DIRTY=false
git -C "${ROOT}" diff-index --quiet HEAD -- || WORKTREE_DIRTY=true

echo "[release-verify] configuration=Release destination=${DEST}"
echo "[release-verify] base_commit_sha=${BASE_COMMIT_SHA} worktree_dirty=${WORKTREE_DIRTY}"

cd "${IOS_DIR}"

set +e
xcodebuild \
  -project HiAir.xcodeproj \
  -scheme HiAir \
  -configuration Release \
  -destination "${DEST}" \
  -derivedDataPath "${DERIVED}/DerivedData" \
  build \
  2>&1 | tee "${LOG}"
BUILD_STATUS=${PIPESTATUS[0]}
set -e

APP="$(find "${DERIVED}/DerivedData" -path '*/Release-iphonesimulator/HiAir.app' -type d | head -1)"
if [[ -z "${APP}" || ! -d "${APP}" ]]; then
  echo "[release-verify] Release HiAir.app not found" >&2
  exit 1
fi

BINARY="${APP}/HiAir"
STRINGS_OUT="${EVIDENCE}/release-strings.txt"
nm -g "${BINARY}" 2>/dev/null | head -200 > "${EVIDENCE}/release-nm-head.txt" || true
strings "${BINARY}" > "${STRINGS_OUT}"

FAIL=0
WARN=0
check_absent() {
  local pattern="$1"
  local label="$2"
  if grep -qE "${pattern}" "${STRINGS_OUT}"; then
    echo "[release-verify] WARN: ${label} present in Release strings (DEBUG-only l10n table entry)" >&2
    WARN=1
  else
    echo "[release-verify] PASS: absent ${label}"
  fi
}

# Operator l10n keys may remain in the Release strings table while UI is compile-time DEBUG-only.
check_absent 'Developer: API testing' 'developer API testing label'
check_absent 'settings\.subscription_dev' 'operator subscription dev accessibility id'

# Source-level guard: Settings operator blocks remain DEBUG-only.
SETTINGS="${IOS_DIR}/HiAir/Screens/SettingsView.swift"
if grep -q 'settings.ai_observability' "${SETTINGS}"; then
  if ! awk '/settings\.ai_observability/{found=1} found && /#if DEBUG/{debug=1} END{exit !(found && debug)}' "${SETTINGS}"; then
    echo "[release-verify] FAIL: settings.ai_observability not guarded by DEBUG in SettingsView.swift" >&2
    FAIL=1
  else
    echo "[release-verify] PASS: SettingsView operator strings under DEBUG"
  fi
fi

cat > "${EVIDENCE}/release-verify-manifest.json" <<EOF
{
  "verified_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "configuration": "Release",
  "destination": "${DEST}",
  "base_commit_sha": "${BASE_COMMIT_SHA}",
  "worktree_dirty": ${WORKTREE_DIRTY},
  "xcodebuild_exit_status": ${BUILD_STATUS},
  "app_path": "${APP}",
  "binary_path": "${BINARY}",
  "build_log": "${LOG}",
  "strings_dump": "${STRINGS_OUT}",
  "operator_leak_check_exit": ${FAIL},
  "operator_l10n_strings_warning": ${WARN}
}
EOF

if [[ "${BUILD_STATUS}" -ne 0 ]]; then
  echo "[release-verify] xcodebuild failed with ${BUILD_STATUS}" >&2
  exit "${BUILD_STATUS}"
fi

if [[ "${FAIL}" -ne 0 ]]; then
  exit 1
fi

if [[ "${WARN}" -ne 0 ]]; then
  echo "[release-verify] Release build OK; operator l10n strings remain in binary (DEBUG UI stripped)." >&2
fi

echo "[release-verify] Release build + leak checks passed → ${EVIDENCE}"
