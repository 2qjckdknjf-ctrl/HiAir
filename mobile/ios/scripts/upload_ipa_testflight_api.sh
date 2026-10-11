#!/usr/bin/env bash
# Upload HiAir.ipa to App Store Connect / TestFlight using App Store Connect API key.
# IPA must be built with Xcode 26+ (iOS 26 SDK). Prefer Xcode Cloud — see docs/release/XCODE_CLOUD_SETUP.md.
# Requires: APPLE_ISSUER_ID (UUID from ASC → Users and Access → Integrations → API).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUARD_PYTHON="$ROOT/../../.venv312/bin/python"
if [[ ! -x "$GUARD_PYTHON" ]]; then GUARD_PYTHON=/usr/bin/python3; fi
MANIFEST="${IPA_MANIFEST_PATH:-$ROOT/build/latest-release.json}"
IPA="${IPA_PATH:-}"
if [[ -z "$IPA" && -f "$MANIFEST" ]]; then
  IPA="$(MANIFEST_PATH="$MANIFEST" "$GUARD_PYTHON" -c 'import json,os; print(json.load(open(os.environ["MANIFEST_PATH"]))["artifacts"][0]["path"])')"
fi
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
if [[ ! -f "$MANIFEST" ]]; then
  echo "error: a signed artifact source/hash manifest is required before upload." >&2
  exit 1
fi
"$GUARD_PYTHON" "$ROOT/../../scripts/release/check_mobile_release_source.py" \
  --artifact "$IPA" --manifest "$MANIFEST"

if [[ ! -f "$KEY_PATH" ]]; then
  echo "error: API key not found: $KEY_PATH" >&2
  exit 1
fi

mkdir -p "$HOME/.private_keys"
install -m 600 "$KEY_PATH" "$HOME/.private_keys/AuthKey_${KEY_ID}.p8"

echo "==> Upload $IPA"
xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$KEY_ID" --apiIssuer "$ISSUER"

echo "==> Upload submitted. Check TestFlight processing in App Store Connect."
