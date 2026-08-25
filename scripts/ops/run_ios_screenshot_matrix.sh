#!/usr/bin/env bash
# Run iOS screenshot matrix cells (simulator captures with provenance).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CAPTURE="${ROOT}/scripts/ops/capture_ios_screenshots.sh"
MATRIX_ROOT="${ROOT}/.evidence/ios-matrix/$(date +%Y%m%d-%H%M%S)"
mkdir -p "${MATRIX_ROOT}"

run_cell() {
  local slug="$1"
  shift
  local out="${MATRIX_ROOT}/${slug}"
  mkdir -p "${out}"
  echo "[matrix] cell=${slug}"
  env "$@" HIAIR_SCREENSHOT_OUT="${out}" bash "${CAPTURE}"
}

run_cell "iphone-16e-en-standard" IOS_SIMULATOR_NAME="iPhone 16e" HIAIR_SHOT_LANGUAGE=en HIAIR_SHOT_ACCESSIBILITY=standard
run_cell "iphone-17pro-en-standard" IOS_SIMULATOR_NAME="iPhone 17 Pro" HIAIR_SHOT_LANGUAGE=en HIAIR_SHOT_ACCESSIBILITY=standard
run_cell "iphone-17pro-ru-standard" IOS_SIMULATOR_NAME="iPhone 17 Pro" HIAIR_SHOT_LANGUAGE=ru HIAIR_SHOT_ACCESSIBILITY=standard
run_cell "ipad-pro-13-en-standard" IOS_SIMULATOR_NAME="iPad Pro 13-inch (M5)" HIAIR_SHOT_LANGUAGE=en HIAIR_SHOT_ACCESSIBILITY=standard
run_cell "ipad-pro-13-ru-standard" IOS_SIMULATOR_NAME="iPad Pro 13-inch (M5)" HIAIR_SHOT_LANGUAGE=ru HIAIR_SHOT_ACCESSIBILITY=standard
run_cell "iphone-17pro-en-a11y3" IOS_SIMULATOR_NAME="iPhone 17 Pro" HIAIR_SHOT_LANGUAGE=en HIAIR_SHOT_ACCESSIBILITY=accessibility3
run_cell "iphone-17pro-en-a11y5" IOS_SIMULATOR_NAME="iPhone 17 Pro" HIAIR_SHOT_LANGUAGE=en HIAIR_SHOT_ACCESSIBILITY=accessibility5
run_cell "iphone-17pro-en-reduce-motion" IOS_SIMULATOR_NAME="iPhone 17 Pro" HIAIR_SHOT_LANGUAGE=en HIAIR_SHOT_REDUCE_MOTION=1
run_cell "iphone-17pro-en-reduce-transparency" IOS_SIMULATOR_NAME="iPhone 17 Pro" HIAIR_SHOT_LANGUAGE=en HIAIR_SHOT_REDUCE_TRANSPARENCY=1

run_matrix_state() {
  local slug="$1"
  local test_name="$2"
  shift 2
  local out="${MATRIX_ROOT}/${slug}"
  mkdir -p "${out}"
  echo "[matrix] state=${slug}"
  env "$@" HIAIR_SCREENSHOT_OUT="${out}" bash -c "
    set -euo pipefail
    cd '${ROOT}/mobile/ios'
    SIM_JSON=\$(bash '${OPS}/resolve_ios_simulator.sh' \"\${IOS_SIMULATOR_NAME:-iPhone 17 Pro}\")
    DEST=\$(python3 -c \"import json,sys; print(json.loads(sys.argv[1])['destination'])\" \"\${SIM_JSON}\")
    xcodebuild -project HiAir.xcodeproj -scheme HiAir -destination \"\${DEST}\" test \
      -only-testing:HiAirUITests/MatrixStateScreenshotTests/${test_name} \
      TEST_RUNNER_HIAIR_SCREENSHOT_OUT=\"${out}\" \
      TEST_RUNNER_HIAIR_SHOT_LANGUAGE=\"\${HIAIR_SHOT_LANGUAGE:-en}\" \
      TEST_RUNNER_HIAIR_REPORT_SHOT_ENV=1
  "
}

run_matrix_state "iphone-17pro-en-loading" "testCaptureDashboardLoading" IOS_SIMULATOR_NAME="iPhone 17 Pro" HIAIR_SHOT_LANGUAGE=en
run_matrix_state "iphone-17pro-en-empty" "testCaptureDashboardEmpty" IOS_SIMULATOR_NAME="iPhone 17 Pro" HIAIR_SHOT_LANGUAGE=en
run_matrix_state "iphone-17pro-en-error" "testCaptureDashboardError" IOS_SIMULATOR_NAME="iPhone 17 Pro" HIAIR_SHOT_LANGUAGE=en
run_matrix_state "iphone-17pro-en-offline" "testCaptureDashboardOfflineStale" IOS_SIMULATOR_NAME="iPhone 17 Pro" HIAIR_SHOT_LANGUAGE=en
run_matrix_state "iphone-17pro-en-account-deletion" "testCaptureAccountDeletionRecovery" IOS_SIMULATOR_NAME="iPhone 17 Pro" HIAIR_SHOT_LANGUAGE=en

python3 - <<'PY' "${MATRIX_ROOT}" "${ROOT}"
import json, os, sys
matrix_root, root = sys.argv[1], sys.argv[2]
cells = []
for name in sorted(os.listdir(matrix_root)):
    cell_dir = os.path.join(matrix_root, name)
    manifest = os.path.join(cell_dir, "capture-manifest.json")
    if os.path.isfile(manifest):
        with open(manifest, encoding="utf-8") as handle:
            cells.append({"slug": name, "manifest": json.load(handle)})
out = os.path.join(matrix_root, "matrix-index.json")
with open(out, "w", encoding="utf-8") as handle:
    json.dump({"cells": cells}, handle, indent=2)
    handle.write("\n")
print(out)
PY

echo "[matrix] complete → ${MATRIX_ROOT}"
