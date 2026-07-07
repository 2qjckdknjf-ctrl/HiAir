#!/usr/bin/env bash
# Upload signed AAB to Google Play Internal Testing track.
# Requires: keystore.properties, Play Console service account JSON (owner-provided).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID_DIR="$ROOT/mobile/android"
AAB="$ANDROID_DIR/app/build/outputs/bundle/release/app-release.aab"
KEYSTORE_PROPS="$ANDROID_DIR/keystore.properties"
PLAY_JSON="${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:-$ROOT/backend/.secrets/google-play-service-account.json}"

if [[ ! -f "$KEYSTORE_PROPS" ]]; then
  cat >&2 <<EOF
error: $KEYSTORE_PROPS missing.

Owner steps (one-time):
  1. cd mobile/android
  2. cp keystore.properties.example keystore.properties
  3. Generate or locate release keystore (do NOT commit):
       keytool -genkeypair -v -keystore hiair-release.keystore -alias hiair \\
         -keyalg RSA -keysize 2048 -validity 10000 -storetype PKCS12
  4. Edit keystore.properties with storeFile, passwords, keyAlias
  5. bash scripts/release/build_android_play_internal.sh

See docs/release/ANDROID_RELEASE_SIGNING_GUIDE.md
See docs/release/GOOGLE_PLAY_INTERNAL_CHECKLIST.md (rollback plan)
EOF
  exit 1
fi

bash "$ROOT/scripts/release/build_android_play_internal.sh"

if ! jarsigner -verify -verbose -certs "$AAB" >/dev/null 2>&1; then
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

Alternatively upload AAB manually: Play Console → Testing → Internal testing → Create release
EOF
  exit 1
fi

if ! command -v fastlane >/dev/null 2>&1; then
  echo "error: fastlane not installed. Upload manually in Play Console or install fastlane." >&2
  exit 1
fi

echo "==> Upload via fastlane supply (internal track)"
export SUPPLY_JSON_KEY="$PLAY_JSON"
export SUPPLY_PACKAGE_NAME="${GOOGLE_PLAY_PACKAGE_NAME:-com.hiair}"
fastlane supply --aab "$AAB" --track internal --skip_upload_metadata --skip_upload_images --skip_upload_screenshots

echo "==> Upload submitted. Verify in Play Console → Internal testing."
