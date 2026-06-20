#!/usr/bin/env bash
set -euo pipefail

KEYSTORE_PATH="${1:-upload-keystore.jks}"
KEY_ALIAS="${2:-hiair-upload}"
VALIDITY_DAYS="${3:-10000}"

if [ -f "$KEYSTORE_PATH" ]; then
  echo "Keystore already exists: $KEYSTORE_PATH"
  exit 1
fi

echo "Generating upload keystore at: $KEYSTORE_PATH"
echo "Alias: $KEY_ALIAS"
echo "You will be prompted for keystore and key passwords."

keytool -genkeypair \
  -v \
  -keystore "$KEYSTORE_PATH" \
  -alias "$KEY_ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity "$VALIDITY_DAYS" \
  -dname "CN=HiAir, OU=Mobile, O=HiAir, L=Unknown, ST=Unknown, C=US"

echo
echo "Keystore created."
echo "Next steps:"
echo "1. Register upload key in Google Play Console (App integrity)."
echo "2. Encode keystore for GitHub secret ANDROID_KEYSTORE_BASE64:"
echo "   base64 -w 0 \"$KEYSTORE_PATH\""
echo "3. Store passwords and alias in GitHub secrets:"
echo "   ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD"
