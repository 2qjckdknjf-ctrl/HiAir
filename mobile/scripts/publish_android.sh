#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_DIR="$ROOT_DIR/mobile/android"
SECRETS_DIR="${HIAIR_SECRETS_DIR:-$HOME/.hiair-secrets}"
SIGNING_ENV="$SECRETS_DIR/signing.env"
TRACK="${1:-internal}"
VERSION_NAME="${ANDROID_VERSION_NAME:-0.1.0}"
VERSION_CODE="${ANDROID_VERSION_CODE:-$(date +%s)}"

mkdir -p "$SECRETS_DIR"

load_env_file() {
  local file="$1"
  if [ -f "$file" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
  fi
}

load_env_file "$ROOT_DIR/.env.local"
load_env_file "$ROOT_DIR/backend/.env.local"
load_env_file "$SECRETS_DIR/signing.env"

resolve_service_account_json() {
  local candidates=(
    "${GOOGLE_PLAY_SERVICE_ACCOUNT_FILE:-}"
    "${GOOGLE_APPLICATION_CREDENTIALS:-}"
    "$SECRETS_DIR/play-service-account.json"
    "$ROOT_DIR/.secrets/play-service-account.json"
    "$ROOT_DIR/mobile/android/secrets/play-service-account.json"
    "$ROOT_DIR/mobile/android/play-service-account.json"
  )

  if [ -n "${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:-}" ]; then
    if [ -f "$GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" ]; then
      echo "$GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"
      return 0
    fi
    local inline_path="$SECRETS_DIR/play-service-account.inline.json"
    printf '%s' "$GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" > "$inline_path"
    chmod 600 "$inline_path"
    echo "$inline_path"
    return 0
  fi

  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

if [ ! -f "$SIGNING_ENV" ]; then
  KEYSTORE_PATH="$SECRETS_DIR/hiair-upload.jks"
  if [ -f "$KEYSTORE_PATH" ]; then
    echo "signing.env missing; replacing orphaned keystore at $KEYSTORE_PATH"
    rm -f "$KEYSTORE_PATH"
  fi

  echo "Generating upload keystore in $SECRETS_DIR"
  STORE_PASS="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
  keytool -genkeypair -v \
    -keystore "$KEYSTORE_PATH" \
    -alias hiair-upload \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -storepass "$STORE_PASS" \
    -keypass "$STORE_PASS" \
    -dname "CN=HiAir, OU=Mobile, O=HiAir, L=Unknown, ST=Unknown, C=US"
  cat > "$SIGNING_ENV" <<EOF
ANDROID_KEYSTORE_PATH=$KEYSTORE_PATH
ANDROID_KEYSTORE_PASSWORD=$STORE_PASS
ANDROID_KEY_ALIAS=hiair-upload
ANDROID_KEY_PASSWORD=$STORE_PASS
EOF
  chmod 600 "$SIGNING_ENV"
  set -a
  # shellcheck disable=SC1090
  source "$SIGNING_ENV"
  set +a
fi

if [ -z "${ANDROID_KEYSTORE_PATH:-}" ] || [ -z "${ANDROID_KEYSTORE_PASSWORD:-}" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$SIGNING_ENV"
  set +a
fi

if ! python3 -c "import google.oauth2, googleapiclient" >/dev/null 2>&1; then
  python3 -m pip install -r "$ROOT_DIR/mobile/scripts/requirements-android-publish.txt" --quiet
fi

export ANDROID_VERSION_CODE="$VERSION_CODE"
export ANDROID_VERSION_NAME="$VERSION_NAME"

echo "Building signed AAB..."
(cd "$ANDROID_DIR" && ./gradlew :app:bundleRelease --no-daemon)

AAB="$ANDROID_DIR/app/build/outputs/bundle/release/app-release.aab"
python3 "$ROOT_DIR/mobile/scripts/generate_release_manifest.py"

SERVICE_ACCOUNT_JSON="$(resolve_service_account_json || true)"
if [ -z "$SERVICE_ACCOUNT_JSON" ]; then
  echo
  echo "Play service account JSON not found."
  echo "Checked:"
  echo "  - GOOGLE_PLAY_SERVICE_ACCOUNT_JSON (.env.local or env)"
  echo "  - GOOGLE_APPLICATION_CREDENTIALS"
  echo "  - $SECRETS_DIR/play-service-account.json"
  echo "  - $ROOT_DIR/.secrets/play-service-account.json"
  echo "  - $ROOT_DIR/mobile/android/secrets/play-service-account.json"
  echo
  echo "Built AAB ready for manual upload:"
  echo "  $AAB"
  exit 2
fi

echo "Uploading to Google Play track: $TRACK"
python3 "$ROOT_DIR/mobile/scripts/upload_to_google_play.py" \
  --aab "$AAB" \
  --service-account-json "$SERVICE_ACCOUNT_JSON" \
  --track "$TRACK" \
  --release-name "HiAir $VERSION_NAME ($VERSION_CODE)"

echo "Publish complete."
