#!/usr/bin/env bash
# Capture iOS ASC screenshots into docs/brand/store-assets/asc-screenshots/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS_DIR="${ROOT}/mobile/ios"
OUT="${HIAIR_SCREENSHOT_OUT:-${ROOT}/docs/brand/store-assets/asc-screenshots/captured-iphone}"
DEST="${IOS_SCREENSHOT_DEST:-platform=iOS Simulator,name=iPhone 17 Pro}"

mkdir -p "${OUT}"
export HIAIR_SCREENSHOT_OUT="${OUT}"

echo "[screenshots] destination=${DEST}"
echo "[screenshots] output=${OUT}"

cd "${IOS_DIR}"
xcodebuild \
  -project HiAir.xcodeproj \
  -scheme HiAir \
  -destination "${DEST}" \
  test \
  -only-testing:HiAirUITests/StoreScreenshotTests \
  2>&1 | tail -20

echo "[screenshots] done → ${OUT}"
ls -la "${OUT}"
