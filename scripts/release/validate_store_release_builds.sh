#!/usr/bin/env bash
# Validate release artifacts use production API and expected versioning.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="${1:-all}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

check_android() {
  local apk="$ROOT/mobile/android/app/build/outputs/apk/release/app-release-unsigned.apk"
  local aab="$ROOT/mobile/android/app/build/outputs/bundle/release/app-release.aab"
  local artifact=""
  if [[ -f "$aab" ]]; then
    artifact="$aab"
  elif [[ -f "$apk" ]]; then
    artifact="$apk"
  else
    fail "Android release artifact missing — run scripts/release/build_android_play_internal.sh"
  fi

  echo "==> Android artifact: $artifact"
  if [[ "$artifact" == *.aab ]]; then
    unzip -l "$artifact" | rg -q '\.dex' || fail "invalid Android AAB"
    dex_paths=$(unzip -l "$artifact" | awk '/\.dex/{print $4}')
  else
    unzip -l "$artifact" | rg -q '\.dex' || fail "invalid Android artifact"
    dex_paths=$(unzip -l "$artifact" | awk '/\.dex/{print $4}')
  fi

  local found_prod=0
  local dex
  local blob
  while IFS= read -r dex; do
    [[ -z "$dex" ]] && continue
    blob="$(unzip -p "$artifact" "$dex" | strings || true)"
    if [[ "$blob" == *"https://api.hiair.io"* ]]; then
      found_prod=1
    fi
    if [[ "$blob" == *"10.0.2.2:8000"* ]]; then
      fail "debug API URL found in release artifact"
    fi
  done <<< "$dex_paths"
  [[ "$found_prod" -eq 1 ]] || fail "production API URL not found in release artifact"
  echo "PASS Android production API"
}

check_ios_config() {
  echo "==> iOS Release configuration"
  rg -q 'let defaultBaseURL = "https://api.hiair.io"' "$ROOT/mobile/ios/HiAir/Networking/APIClient.swift" \
    || fail "iOS Release defaultBaseURL missing"
  rg -q 'CURRENT_PROJECT_VERSION: 13' "$ROOT/mobile/ios/project.yml" \
    || fail "iOS build number mismatch in project.yml"
  test -f "$ROOT/mobile/ios/HiAir/PrivacyInfo.xcprivacy" \
    || fail "PrivacyInfo.xcprivacy missing"
  echo "PASS iOS release config"
}

case "$TARGET" in
  android) check_android ;;
  ios) check_ios_config ;;
  all)
    check_android
    check_ios_config
    ;;
  *)
    echo "Usage: $0 [android|ios|all]" >&2
    exit 2
    ;;
esac

echo "validate_store_release_builds: PASS"
