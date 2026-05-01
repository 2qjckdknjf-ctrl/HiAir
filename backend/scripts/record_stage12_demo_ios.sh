#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IOS_ROOT="${REPO_ROOT}/mobile/ios"
SIM_UDID="${SIM_UDID:-2D996686-433A-43B0-BFD3-0954C72B65B9}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/hiair-demo-dd}"
OUTPUT_PATH="${OUTPUT_PATH:-${REPO_ROOT}/docs/_operator/stage12-demo-ios.mp4}"
RECORD_SECONDS="${RECORD_SECONDS:-20}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.hiair.app}"

echo "[INFO] Using simulator: ${SIM_UDID}"
echo "[INFO] Output video: ${OUTPUT_PATH}"

open -a Simulator
sleep 2
xcrun simctl boot "${SIM_UDID}" || true
xcrun simctl bootstatus "${SIM_UDID}" -b

xcodebuild \
  -project "${IOS_ROOT}/HiAir.xcodeproj" \
  -scheme "HiAir" \
  -sdk iphonesimulator \
  -configuration Debug \
  -destination "id=${SIM_UDID}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  build \
  CODE_SIGNING_ALLOWED=NO

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/HiAir.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "[ERROR] App bundle not found at ${APP_PATH}"
  exit 1
fi

xcrun simctl install "${SIM_UDID}" "${APP_PATH}"
xcrun simctl launch "${SIM_UDID}" "${APP_BUNDLE_ID}"

mkdir -p "$(dirname "${OUTPUT_PATH}")"
rm -f "${OUTPUT_PATH}"

echo "[INFO] Recording for ${RECORD_SECONDS}s..."
xcrun simctl io "${SIM_UDID}" recordVideo "${OUTPUT_PATH}" &
REC_PID=$!
sleep "${RECORD_SECONDS}"
kill -INT "${REC_PID}" || true
wait "${REC_PID}" || true

if [[ ! -f "${OUTPUT_PATH}" ]]; then
  echo "[ERROR] Recording file not created: ${OUTPUT_PATH}"
  exit 1
fi

echo "[OK] Demo recording saved: ${OUTPUT_PATH}"
