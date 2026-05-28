#!/usr/bin/env bash
# Extract HiAir app icon + Android launcher foreground from brand mockup.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${HIAIR_ICON_SOURCE:-/Users/alex/.cursor/projects/Users-alex-Projects-HIAir/assets/ChatGPT_Image_27_____2026__.__22_04_59__2_-9f1ea182-848e-411c-9f96-4057f49f1051.png}"
WORK="$(mktemp -d)"
CROP_H=420
CROP_W=420
CROP_TOP=72
CROP_LEFT=302

IOS_ICON="$ROOT/mobile/ios/HiAir/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
AND_FG="$ROOT/mobile/android/app/src/main/res/drawable/ic_hiair_launcher_foreground.png"

cp "$SRC" "$WORK/source.png"
sips --cropToHeightWidth "$CROP_H" "$CROP_W" --cropOffset "$CROP_TOP" "$CROP_LEFT" \
  "$WORK/source.png" --out "$WORK/icon-crop.png" >/dev/null
sips -s format png -z 1024 1024 "$WORK/icon-crop.png" --out "$IOS_ICON" >/dev/null
sips -s format png -z 432 432 "$WORK/icon-crop.png" --out "$AND_FG" >/dev/null
rm -rf "$WORK"
echo "Wrote $IOS_ICON"
echo "Wrote $AND_FG"
