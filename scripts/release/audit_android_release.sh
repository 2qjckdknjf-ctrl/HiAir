#!/usr/bin/env bash
# Stage 1 Android release audit — build config, manifest, artifacts (no keystore required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID_DIR="$ROOT/mobile/android"
GRADLE="$ANDROID_DIR/app/build.gradle.kts"
MANIFEST="$ANDROID_DIR/app/src/main/AndroidManifest.xml"

export JAVA_HOME="${JAVA_HOME:-/Users/alex/Library/Java/JavaVirtualMachines/jbr-17.0.14/Contents/Home}"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

echo "==> HiAir Android Release Audit"
echo ""

# Application ID & versioning
rg -q 'applicationId = "com.hiair"' "$GRADLE" || fail "applicationId must be com.hiair"
pass "applicationId com.hiair"
rg -q 'versionCode = [0-9]+' "$GRADLE" || fail "versionCode missing"
rg -q 'versionName = "' "$GRADLE" || fail "versionName missing"
pass "versionCode/versionName declared"

# Release API
rg -q 'API_BASE_URL.*https://api.hiair.io' "$GRADLE" || fail "release API_BASE_URL must be api.hiair.io"
pass "release API https://api.hiair.io"

# Cleartext off in release
rg -q 'usesCleartextTraffic.*false' "$GRADLE" || fail "release cleartext must be false"
pass "release cleartext disabled"

# Signing scaffold
test -f "$ANDROID_DIR/keystore.properties.example" || fail "keystore.properties.example missing"
if [[ -f "$ANDROID_DIR/keystore.properties" ]]; then
  pass "keystore.properties present (signed build path)"
else
  echo "WARN: keystore.properties missing — unsigned AAB only (owner action)"
fi

# Manifest permissions
rg -q 'POST_NOTIFICATIONS' "$MANIFEST" || fail "POST_NOTIFICATIONS permission missing"
rg -q 'health.READ_STEPS' "$MANIFEST" || fail "Health Connect steps permission missing"
rg -q 'VIEW_PERMISSION_USAGE' "$MANIFEST" || fail "Health Connect VIEW_PERMISSION_USAGE alias missing"
rg -q 'ACTION_SHOW_PERMISSIONS_RATIONALE' "$MANIFEST" || fail "Health Connect rationale intent missing"
pass "manifest permissions + Health Connect compliance"

# R8 / minify
if rg -q 'isMinifyEnabled = true' "$GRADLE"; then
  pass "R8 minify enabled"
else
  echo "INFO: isMinifyEnabled=false (acceptable for beta; enable before scale)"
fi

# Build
cd "$ANDROID_DIR"
./gradlew :app:bundleRelease :app:testDebugUnitTest :app:lintRelease --no-daemon -q
pass "bundleRelease + unit tests + lintRelease"

# Artifact validation
bash "$ROOT/scripts/release/validate_store_release_builds.sh" android

AAB="$ANDROID_DIR/app/build/outputs/bundle/release/app-release.aab"
if [[ -f "$ANDROID_DIR/keystore.properties" ]]; then
  bash "$ROOT/scripts/release/validate_signed_android_release.sh"
else
  echo "SKIP: signed validation (no keystore.properties)"
fi

echo ""
echo "audit_android_release: PASS"
