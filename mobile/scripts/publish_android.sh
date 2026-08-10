#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_DIR="$ROOT_DIR/mobile/android"
SECRETS_DIR="${HIAIR_SECRETS_DIR:-$HOME/.hiair-secrets}"
SIGNING_ENV="$SECRETS_DIR/signing.env"
SERVICE_ACCOUNT_JSON="$SECRETS_DIR/play-service-account.json"
TRACK="${1:-internal}"
VERSION_NAME="${ANDROID_VERSION_NAME:-0.1.0}"
VERSION_CODE="${ANDROID_VERSION_CODE:-1}"

mkdir -p "$SECRETS_DIR"

if [ ! -f "$SIGNING_ENV" ]; then
  echo "Generating upload keystore in $SECRETS_DIR"
  bash "$ROOT_DIR/mobile/android/scripts/generate_upload_keystore.sh" "$SECRETS_DIR/hiair-upload.jks" hiair-upload
  STORE_PASS="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
  rm -f "$SECRETS_DIR/hiair-upload.jks"
  keytool -genkeypair -v \
    -keystore "$SECRETS_DIR/hiair-upload.jks" \
    -alias hiair-upload \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -storepass "$STORE_PASS" \
    -keypass "$STORE_PASS" \
    -dname "CN=HiAir, OU=Mobile, O=HiAir, L=Unknown, ST=Unknown, C=US"
  cat > "$SIGNING_ENV" <<EOF
ANDROID_KEYSTORE_PATH=$SECRETS_DIR/hiair-upload.jks
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
