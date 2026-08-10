#!/usr/bin/env bash
set -euo pipefail

# Requires a GitHub PAT with repo/admin:repo_hook or actions secrets write access.
# Usage:
#   GH_ADMIN_TOKEN=ghp_... bash mobile/scripts/sync_android_github_secrets.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SECRETS_DIR="${HIAIR_SECRETS_DIR:-$HOME/.hiair-secrets}"
SIGNING_ENV="$SECRETS_DIR/signing.env"
SERVICE_ACCOUNT_JSON="$SECRETS_DIR/play-service-account.json"
REPO="${GITHUB_REPOSITORY:-2qjckdknjf-ctrl/HiAir}"

if [ -z "${GH_ADMIN_TOKEN:-}" ]; then
  echo "Set GH_ADMIN_TOKEN with secrets write permission."
  exit 1
fi

if [ ! -f "$SIGNING_ENV" ]; then
  echo "Missing $SIGNING_ENV. Run mobile/scripts/publish_android.sh first."
  exit 1
fi

if [ ! -f "$SERVICE_ACCOUNT_JSON" ]; then
  echo "Missing $SERVICE_ACCOUNT_JSON"
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$SIGNING_ENV"
set +a

export GH_TOKEN="$GH_ADMIN_TOKEN"

gh secret set ANDROID_KEYSTORE_BASE64 --repo "$REPO" --body "$(base64 -w 0 "$ANDROID_KEYSTORE_PATH")"
gh secret set ANDROID_KEYSTORE_PASSWORD --repo "$REPO" --body "$ANDROID_KEYSTORE_PASSWORD"
gh secret set ANDROID_KEY_ALIAS --repo "$REPO" --body "$ANDROID_KEY_ALIAS"
gh secret set ANDROID_KEY_PASSWORD --repo "$REPO" --body "$ANDROID_KEY_PASSWORD"
gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON --repo "$REPO" < "$SERVICE_ACCOUNT_JSON"

echo "GitHub secrets synced for $REPO"
