#!/usr/bin/env bash
# Build signed (or unsigned) Google Play release AAB for Internal Testing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID_DIR="$ROOT/mobile/android"
cd "$ANDROID_DIR"

if [[ -f keystore.properties ]]; then
  echo "==> keystore.properties found — release AAB will be signed"
elif [[ -n "${ANDROID_KEYSTORE_PATH:-}" ]]; then
  echo "==> ANDROID_KEYSTORE_PATH set — release AAB will be signed via env vars"
else
  echo "warn: no signing config — AAB will be unsigned (Play Console will reject upload)"
  echo "  bash scripts/release/investigate_android_keystore.sh"
  echo "  docs/release/ANDROID_RELEASE_SIGNING_GUIDE.md"
fi

./gradlew :app:bundleRelease --no-daemon

AAB="$ANDROID_DIR/app/build/outputs/bundle/release/app-release.aab"
if [[ ! -f "$AAB" ]]; then
  echo "error: AAB not found at $AAB" >&2
  exit 1
fi

echo ""
echo "AAB ready: $AAB"
echo "Verify: bash scripts/release/validate_store_release_builds.sh android"
