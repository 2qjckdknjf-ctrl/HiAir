#!/usr/bin/env bash
# Verify a shipped HiAir iOS archive/IPA includes HealthKit entitlements and privacy strings.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to.ipa|path-to.xcarchive>" >&2
  exit 2
fi

INPUT="$1"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

APP_PATH=""
if [[ -d "$INPUT/Products/Applications/HiAir.app" ]]; then
  APP_PATH="$INPUT/Products/Applications/HiAir.app"
elif [[ "$INPUT" == *.ipa ]]; then
  unzip -q "$INPUT" -d "$WORKDIR"
  APP_PATH="$(find "$WORKDIR/Payload" -maxdepth 1 -name '*.app' | head -n 1)"
else
  echo "error: unsupported input: $INPUT" >&2
  exit 2
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "error: HiAir.app not found in archive" >&2
  exit 1
fi

echo "==> App: $APP_PATH"

ENT="$WORKDIR/entitlements.plist"
codesign -d --entitlements :- "$APP_PATH" > "$ENT" 2>/dev/null || true

if /usr/libexec/PlistBuddy -c "Print :com.apple.developer.healthkit" "$ENT" >/dev/null 2>&1; then
  echo "OK  entitlement com.apple.developer.healthkit present"
else
  echo "FAIL entitlement com.apple.developer.healthkit missing (App ID capability / provisioning profile)" >&2
  exit 1
fi

INFO="$APP_PATH/Info.plist"
for key in NSHealthShareUsageDescription NSHealthUpdateUsageDescription; do
  if /usr/libexec/PlistBuddy -c "Print :$key" "$INFO" >/dev/null 2>&1; then
    echo "OK  Info.plist $key present"
  else
    echo "FAIL Info.plist $key missing" >&2
    exit 1
  fi
done

BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO" 2>/dev/null || echo '?')"
echo "OK  CFBundleVersion=$BUILD"

if [[ -f "$APP_PATH/PrivacyInfo.xcprivacy" ]]; then
  echo "OK  PrivacyInfo.xcprivacy present"
else
  echo "FAIL PrivacyInfo.xcprivacy missing from app bundle" >&2
  exit 1
fi

echo "==> HealthKit packaging looks valid"
