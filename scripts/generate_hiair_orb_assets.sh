#!/usr/bin/env bash
# Extract HiAir brand orb PNG from approved mockup for iOS/Android assets.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${HIAIR_ORB_SOURCE:-/Users/alex/.cursor/projects/Users-alex-Projects-HIAir/assets/ChatGPT_Image_27_____2026__.__22_04_59__3_-c2cc393b-7885-463e-814b-dff973f99874.png}"
WORK="$(mktemp -d)"
CROP_H=320
CROP_W=320
CROP_TOP=100
CROP_LEFT=128

IOS_SET="$ROOT/mobile/ios/HiAir/Assets.xcassets/HiAirOrb.imageset"
AND_DRAWABLE="$ROOT/mobile/android/app/src/main/res/drawable"

mkdir -p "$IOS_SET" "$AND_DRAWABLE"
cp "$SRC" "$WORK/source.png"

sips --cropToHeightWidth "$CROP_H" "$CROP_W" --cropOffset "$CROP_TOP" "$CROP_LEFT" \
  "$WORK/source.png" --out "$WORK/orb-master.png" >/dev/null
sips -s format png -z 128 128 "$WORK/orb-master.png" --out "$IOS_SET/HiAirOrb.png" >/dev/null
sips -s format png -z 256 256 "$WORK/orb-master.png" --out "$IOS_SET/HiAirOrb@2x.png" >/dev/null
sips -s format png -z 384 384 "$WORK/orb-master.png" --out "$IOS_SET/HiAirOrb@3x.png" >/dev/null

sips -s format png -z 192 192 "$WORK/orb-master.png" --out "$AND_DRAWABLE/hiair_orb.png" >/dev/null

rm -rf "$WORK"
echo "Wrote iOS HiAirOrb.imageset (128/256/384) and Android drawable/hiair_orb.png"
