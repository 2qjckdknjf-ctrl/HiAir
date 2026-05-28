#!/usr/bin/env bash
# Capture iOS simulator screenshots for brand QA (requires built .app).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$ROOT/mobile/ios"
SCHEME="HiAir"
DEVICE="${HIAIR_SIM_DEVICE:-iPhone 15}"
BUCKET="${HIAIR_OUT_BUCKET:-standard}"
OUT_DIR="$ROOT/docs/brand/screenshots/ios/$BUCKET"
# Per-destination DerivedData avoids actool/thinning + build.db corruption when switching simulators.
DEVICE_SLUG="$(echo "$DEVICE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_')"
DERIVED="$IOS_DIR/build/DerivedData-$DEVICE_SLUG"
APP_PATH=""

mkdir -p "$OUT_DIR"

echo "== Building HiAir for simulator =="
cd "$IOS_DIR"
# Serialize builds: parallel xcodebuild against the same DerivedData causes build.db lock/I/O errors.
LOCK_DIR="${DERIVED}/.capture_build.lockdir"
mkdir -p "$DERIVED"
acquire_build_lock() {
  local waited=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    sleep 2
    waited=$((waited + 2))
    if [[ $waited -ge 600 ]]; then
      echo "Timed out waiting for xcodebuild lock ($LOCK_DIR)" >&2
      return 1
    fi
  done
}
release_build_lock() { rmdir "$LOCK_DIR" 2>/dev/null || true; }
acquire_build_lock
trap release_build_lock EXIT
xcodebuild -project HiAir.xcodeproj -scheme "$SCHEME" -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED" \
  build || {
  echo "xcodebuild failed for $DEVICE (see log above)" >&2
  exit 1
}
release_build_lock
trap - EXIT

APP_PATH=$(find "$DERIVED/Build/Products" -name 'HiAir.app' -type d | head -1)
if [[ -z "$APP_PATH" ]]; then
  echo "HiAir.app not found" >&2
  exit 1
fi

UDID=$(xcrun simctl list devices available | grep -F "$DEVICE (" | head -1 | grep -Eo '[A-F0-9-]{36}' | head -1 || true)
if [[ -z "$UDID" ]]; then
  # Prefer exact line match when device name contains regex metacharacters e.g. "(3rd generation)"
  UDID=$(xcrun simctl list devices available | awk -v d="$DEVICE" '$0 ~ "^[[:space:]]+" d " \\(" {print; exit}' | grep -Eo '[A-F0-9-]{36}' | head -1 || true)
fi
if [[ -z "$UDID" ]]; then
  echo "Simulator '$DEVICE' not found. Install via Xcode." >&2
  exit 1
fi

echo "== Booting simulator $DEVICE ($UDID) =="
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl launch "$UDID" com.hiair.app || true
sleep 4
xcrun simctl io "$UDID" screenshot "$OUT_DIR/dashboard.png"
echo "Saved $OUT_DIR/dashboard.png"
echo "Note: Auth-gated screens require manual login for full coverage."
