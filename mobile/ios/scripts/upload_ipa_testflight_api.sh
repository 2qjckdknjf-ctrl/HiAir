#!/usr/bin/env bash
# Upload HiAir.ipa to App Store Connect / TestFlight using App Store Connect API key.
# IPA must be built with Xcode 26+ (iOS 26 SDK). Prefer Xcode Cloud — see docs/release/XCODE_CLOUD_SETUP.md.
# Requires: APPLE_ISSUER_ID (UUID from ASC → Users and Access → Integrations → API).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IPA="${IPA_PATH:-$ROOT/build/export/HiAir.ipa}"
KEY_ID="${APPLE_KEY_ID:-VCL6R84SP3}"
KEY_PATH="${APPLE_KEY_PATH:-$ROOT/../../backend/.secrets/AuthKey_${KEY_ID}.p8}"
ISSUER="${APPLE_ISSUER_ID:-}"

if [[ -z "$ISSUER" && -f "$ROOT/../../backend/.secrets/apple_issuer_id" ]]; then
  ISSUER="$(tr -d '[:space:]' < "$ROOT/../../backend/.secrets/apple_issuer_id")"
fi

if [[ -z "$ISSUER" ]]; then
  echo "error: APPLE_ISSUER_ID is required (UUID from App Store Connect → Integrations → App Store Connect API)." >&2
  echo "  export APPLE_ISSUER_ID='<issuer-uuid>'" >&2
  echo "  or save it to backend/.secrets/apple_issuer_id (one line, gitignored)." >&2
  exit 1
fi

if [[ ! -f "$IPA" ]]; then
  echo "error: IPA not found: $IPA (run scripts/archive_and_upload_testflight.sh first)" >&2
  exit 1
fi

if [[ ! -f "$KEY_PATH" ]]; then
  echo "error: API key not found: $KEY_PATH" >&2
  exit 1
fi

mkdir -p "$HOME/.private_keys"
install -m 600 "$KEY_PATH" "$HOME/.private_keys/AuthKey_${KEY_ID}.p8"

echo "==> Validate API key (list apps)"
xcrun altool --list-apps --apiKey "$KEY_ID" --apiIssuer "$ISSUER" | head -20

echo "==> Upload $IPA"
xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$KEY_ID" --apiIssuer "$ISSUER"

echo "==> Upload submitted. Check TestFlight processing in App Store Connect."
