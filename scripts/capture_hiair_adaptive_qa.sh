#!/usr/bin/env bash
# Capture iOS simulator screenshots across layout buckets for brand QA.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CAPTURE="$ROOT/scripts/capture_hiair_ios_screenshots.sh"

run_capture() {
  local device="$1"
  local bucket="$2"
  echo ""
  echo "========== $bucket ($device) =========="
  HIAIR_SIM_DEVICE="$device" HIAIR_OUT_BUCKET="$bucket" "$CAPTURE"
}

run_capture "iPhone SE (3rd generation)" "compact"
run_capture "iPhone 15" "standard"
run_capture "iPhone 15 Pro Max" "large"
run_capture "iPad Air (5th generation)" "tablet"

echo ""
echo "Adaptive QA captures complete under docs/brand/screenshots/ios/"
