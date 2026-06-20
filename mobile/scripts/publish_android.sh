#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_DIR="$ROOT_DIR/mobile/android"
SECRETS_DIR="${HIAIR_SECRETS_DIR:-$HOME/.hiair-secrets}"
SIGNING_ENV="$SECRETS_DIR/signing.env"
SERVICE_ACCOUNT_JSON="$SECRETS_DIR/play-service-account.json"
TRACK="${1:-internal}"
VERSION_NAME="${ANDROID_VERSION_NAME:-0.1.0}"
VERSION_CODE="${ANDROID_VERSION_CODE:-$(date +%s)}"

mkdir -p "$SECRETS_DIR"

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
fi

# shellcheck disable=SC1090
set -a
source "$SIGNING_ENV"
set +a

if [ -f "$SERVICE_ACCOUNT_JSON" ] && ! python3 -c "import google.oauth2, googleapiclient" >/dev/null 2>&1; then
  echo "Missing Python dependencies for Google Play upload."
  echo "Install them with:"
  echo "  python3 -m pip install -r $ROOT_DIR/mobile/scripts/requirements-android-publish.txt"
  exit 1
fi

export ANDROID_VERSION_CODE="$VERSION_CODE"
export ANDROID_VERSION_NAME="$VERSION_NAME"

echo "Building signed AAB..."
(cd "$ANDROID_DIR" && ./gradlew :app:bundleRelease --no-daemon)

AAB="$ANDROID_DIR/app/build/outputs/bundle/release/app-release.aab"
python3 "$ROOT_DIR/mobile/scripts/generate_release_manifest.py"

if [ ! -f "$SERVICE_ACCOUNT_JSON" ]; then
  echo
  echo "Play service account JSON not found: $SERVICE_ACCOUNT_JSON"
  echo "Place Google Play service account key at that path, then rerun:"
  echo "  bash mobile/scripts/publish_android.sh $TRACK"
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
