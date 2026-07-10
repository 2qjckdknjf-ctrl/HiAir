#!/usr/bin/env bash
# Upload signed AAB to Google Play Internal Testing track.
# Requires: keystore.properties, Play Console service account JSON (owner-provided).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID_DIR="$ROOT/mobile/android"
AAB="$ANDROID_DIR/app/build/outputs/bundle/release/app-release.aab"
KEYSTORE_PROPS="$ANDROID_DIR/keystore.properties"
PLAY_JSON="${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:-$ROOT/backend/.secrets/google-play-service-account.json}"
JAVA_HOME="${JAVA_HOME:-/Users/alex/Library/Java/JavaVirtualMachines/jbr-17.0.14/Contents/Home}"
JARSIGNER="$JAVA_HOME/bin/jarsigner"
PYTHON="${HIAIR_GATE_PYTHON:-$ROOT/.venv312/bin/python}"

if [[ ! -f "$KEYSTORE_PROPS" ]]; then
  cat >&2 <<EOF
error: $KEYSTORE_PROPS missing.

See docs/release/ANDROID_RELEASE_SIGNING_GUIDE.md
EOF
  exit 1
fi

bash "$ROOT/scripts/release/build_android_play_internal.sh"

if ! "$JARSIGNER" -verify "$AAB" >/dev/null 2>&1; then
  echo "error: AAB is not signed — check keystore.properties" >&2
  exit 1
fi

if [[ ! -f "$PLAY_JSON" ]]; then
  cat >&2 <<EOF
error: Play upload credentials missing: $PLAY_JSON

Owner steps:
  1. Play Console → Setup → API access → Link Google Cloud project
  2. Create service account with Release Manager (or Admin) role
  3. Download JSON key to backend/.secrets/google-play-service-account.json (gitignored)
  4. Re-run: GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=... $0

Manual upload: Play Console → Testing → Internal testing → Create release
  AAB: $AAB
  Release notes: docs/release/store/RELEASE_NOTES.md
EOF
  exit 1
fi

if command -v fastlane >/dev/null 2>&1; then
  echo "==> Upload via fastlane supply (internal track)"
  export SUPPLY_JSON_KEY="$PLAY_JSON"
  export SUPPLY_PACKAGE_NAME="${GOOGLE_PLAY_PACKAGE_NAME:-com.hiair}"
  fastlane supply --aab "$AAB" --track internal --skip_upload_metadata --skip_upload_images --skip_upload_screenshots
elif [[ -x "$PYTHON" ]] && "$PYTHON" -c "import googleapiclient.discovery" >/dev/null 2>&1; then
  echo "==> Upload via Google Play API (internal track)"
  GOOGLE_PLAY_SERVICE_ACCOUNT_JSON="$PLAY_JSON" "$PYTHON" "$ROOT/scripts/release/upload_play_internal.py" --track internal
else
  echo "error: install fastlane or run: .venv312/bin/pip install google-api-python-client google-auth google-auth-httplib2" >&2
  exit 1
fi

echo "==> Upload submitted. Verify in Play Console → Internal testing."
