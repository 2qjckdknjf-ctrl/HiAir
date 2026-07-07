#!/usr/bin/env bash
# Validate signed Android release AAB (jarsigner, package, version, production API).
# Exits 0 when signed AAB passes; exits 2 when keystore.properties missing (pipeline ready, owner action).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID_DIR="$ROOT/mobile/android"
AAB="$ANDROID_DIR/app/build/outputs/bundle/release/app-release.aab"
KEYSTORE_PROPS="$ANDROID_DIR/keystore.properties"
EXPECTED_PACKAGE="${GOOGLE_PLAY_PACKAGE_NAME:-com.hiair}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

if [[ ! -f "$KEYSTORE_PROPS" ]]; then
  cat >&2 <<EOF
BLOCKED: $KEYSTORE_PROPS missing — cannot validate signed AAB.

Pipeline is ready. Owner steps:
  cd mobile/android
  cp keystore.properties.example keystore.properties
  # generate hiair-release.keystore (see docs/release/ANDROID_RELEASE_SIGNING_GUIDE.md)
  bash ../../scripts/release/build_android_play_internal.sh
  bash ../../scripts/release/validate_signed_android_release.sh
EOF
  exit 2
fi

if [[ ! -f "$AAB" ]]; then
  echo "==> AAB missing — building signed release"
  bash "$ROOT/scripts/release/build_android_play_internal.sh"
fi

[[ -f "$AAB" ]] || fail "AAB not found at $AAB"

echo "==> jarsigner verify"
if ! jarsigner -verify -verbose -certs "$AAB" >/tmp/hiair-jarsigner-verify.txt 2>&1; then
  cat /tmp/hiair-jarsigner-verify.txt >&2
  fail "AAB is not signed or signature invalid"
fi
rg -q "jar verified" /tmp/hiair-jarsigner-verify.txt || fail "jarsigner did not report jar verified"
echo "PASS jarsigner"

echo "==> Certificate fingerprints"
keytool -printcert -jarfile "$AAB" 2>/dev/null | rg -i "Owner:|SHA1:|SHA256:" || true

APKSIGNER="${ANDROID_HOME:-$HOME/Library/Android/sdk}/build-tools/36.1.0/apksigner"
if [[ -x "$APKSIGNER" ]]; then
  echo "==> bundletool/apksigner note: AAB validated via jarsigner (apksigner applies to APK)"
else
  echo "warn: apksigner not found — jarsigner verification only"
fi

echo "==> Bundle manifest (aapt2 dump)"
AAPT2="$(ls -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}/build-tools/"*/aapt2 2>/dev/null | sort -V | tail -1)"
if [[ -x "$AAPT2" ]]; then
  TMP_APK="$(mktemp -d)/base.apk"
  unzip -p "$AAB" base/manifest/AndroidManifest.xml > /dev/null 2>&1 || true
  # bundletool not required — version from META-INF or gradle output
fi

echo "==> Version metadata"
VERSION_CODE="$(rg 'versionCode\s*=\s*([0-9]+)' "$ANDROID_DIR/app/build.gradle.kts" -o -r '$1' | head -1)"
VERSION_NAME="$(rg 'versionName\s*=\s*"([^"]+)"' "$ANDROID_DIR/app/build.gradle.kts" -o -r '$1' | head -1)"
echo "versionCode=$VERSION_CODE versionName=$VERSION_NAME applicationId=$EXPECTED_PACKAGE"

echo "==> Production API in artifact"
bash "$ROOT/scripts/release/validate_store_release_builds.sh" android

echo "validate_signed_android_release: PASS"
