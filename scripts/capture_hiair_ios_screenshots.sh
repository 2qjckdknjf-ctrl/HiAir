#!/usr/bin/env bash
# Capture iOS simulator screenshots for brand QA (requires built .app).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$ROOT/mobile/ios"
SCHEME="HiAir"
DEVICE="${HIAIR_SIM_DEVICE:-iPhone 15}"
BUCKET="${HIAIR_OUT_BUCKET:-standard}"
OUT_DIR="$ROOT/docs/brand/screenshots/ios/$BUCKET"
DERIVED="$IOS_DIR/build/DerivedData"
APP_PATH=""

mkdir -p "$OUT_DIR"

echo "== Building HiAir for simulator =="
cd "$IOS_DIR"
xcodebuild -scheme "$SCHEME" -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED" \
  build >/dev/null

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
