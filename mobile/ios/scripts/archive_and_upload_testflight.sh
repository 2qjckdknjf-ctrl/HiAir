#!/usr/bin/env bash
# Archive HiAir for App Store / TestFlight upload.
# Requires: Xcode, valid Apple Developer team, App ID com.hiair.app in portal.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
RELEASE_PYTHON="$ROOT/../../.venv312/bin/python"
if [[ ! -x "$RELEASE_PYTHON" ]]; then RELEASE_PYTHON=/usr/bin/python3; fi
SOURCE_SHA="$(git rev-parse HEAD)"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: preserve and commit source changes before a signed release build." >&2
  exit 1
fi
mkdir -p "$ROOT/build/releases"
RELEASE_DIR="$(mktemp -d "$ROOT/build/releases/${SOURCE_SHA:0:12}-XXXXXX")"

SCHEME="HiAir"
PROJECT="HiAir.xcodeproj"
ARCHIVE_PATH="$RELEASE_DIR/HiAir.xcarchive"
EXPORT_PATH="$RELEASE_DIR/export"
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
if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: generated project changed source; commit it before releasing." >&2
  exit 1
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
if [[ "$(git rev-parse HEAD)" != "$SOURCE_SHA" || -n "$(git status --porcelain)" ]]; then
  echo "error: source changed during archive/export; upload is blocked." >&2
  exit 1
fi
SOURCE_SHA="$SOURCE_SHA" IPA_PATH="$IPA" RELEASE_ROOT="$ROOT" "$RELEASE_PYTHON" - <<'PY'
import hashlib, json, os
from pathlib import Path
ipa = Path(os.environ['IPA_PATH'])
manifest = {'ios_source_sha': os.environ['SOURCE_SHA'], 'clean_source': True,
    'artifacts': [{'path': str(ipa.resolve()), 'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest()}]}
ipa.with_suffix('.manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
Path(os.environ['RELEASE_ROOT'], 'build/latest-release.json').write_text(json.dumps(manifest, indent=2) + '\n')
PY

echo ""
echo "Archive ready:"
echo "  $ARCHIVE_PATH"
echo "  $IPA"
echo ""
echo "Upload options:"
echo "  1) Xcode → Organizer → Distribute App → App Store Connect"
echo "  2) Apple Transporter app (drag $IPA)"
echo "  3) IPA_PATH=... IPA_MANIFEST_PATH=... bash scripts/upload_ipa_testflight_api.sh"
