#!/usr/bin/env bash
# Archive HiAir for App Store / TestFlight upload.
# Requires: Xcode, valid Apple Developer team, App ID com.hiair.app in portal.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="HiAir"
PROJECT="HiAir.xcodeproj"
ARCHIVE_PATH="$ROOT/build/HiAir.xcarchive"
EXPORT_PATH="$ROOT/build/export"
EXPORT_OPTIONS="$ROOT/ExportOptions.plist"

echo "==> Regenerate Xcode project (xcodegen)"
XCODEGEN=""
if command -v xcodegen >/dev/null 2>&1; then
  XCODEGEN=xcodegen
elif [[ -x "$ROOT/../../.tools/xcodegen/bin/xcodegen" ]]; then
  XCODEGEN="$ROOT/../../.tools/xcodegen/bin/xcodegen"
fi
if [[ -n "$XCODEGEN" ]]; then
  "$XCODEGEN" generate
else
  echo "warn: xcodegen not found; using existing $PROJECT"
fi

mkdir -p "$ROOT/build"

echo "==> Clean + archive (Release, generic iOS device)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  clean archive \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=43A4KW5BKB \
  -allowProvisioningUpdates

echo "==> Export IPA (app-store-connect)"
rm -rf "$EXPORT_PATH"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

IPA="$EXPORT_PATH/HiAir.ipa"
if [[ ! -f "$IPA" ]]; then
  echo "error: IPA not found at $EXPORT_PATH" >&2
  exit 1
fi

echo ""
echo "Archive ready:"
echo "  $ARCHIVE_PATH"
echo "  $IPA"
echo ""
echo "Upload options:"
echo "  1) Xcode → Organizer → Distribute App → App Store Connect"
echo "  2) Apple Transporter app (drag $IPA)"
echo "  3) xcrun altool --upload-app -f \"$IPA\" --type ios --apiKey ... --apiIssuer ..."
