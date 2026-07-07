#!/usr/bin/env bash
# Mission #4 — exhaustive search for HiAir Android release signing material.
# Does NOT create keystores. Reports findings only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID_DIR="$ROOT/mobile/android"

echo "==> HiAir Android Release Keystore Investigation"
echo "Root: $ROOT"
echo ""

check_path() {
  local label="$1"
  local path="$2"
  if [[ -e "$path" ]]; then
    echo "FOUND: $label -> $path"
    return 0
  fi
  echo "MISS:  $label -> $path"
  return 1
}

found=0

# Convention A (Mission #1–3): keystore.properties + hiair-release.keystore
check_path "keystore.properties" "$ANDROID_DIR/keystore.properties" && found=1 || true
check_path "hiair-release.keystore" "$ANDROID_DIR/hiair-release.keystore" && found=1 || true

# Convention B (PR #27 / android-play-publish branches): env path + upload-keystore.jks
check_path "upload-keystore.jks" "$ANDROID_DIR/upload-keystore.jks" && found=1 || true
check_path "android/.secrets/upload-keystore.jks" "$ANDROID_DIR/.secrets/upload-keystore.jks" && found=1 || true
check_path "backend/.secrets/upload-keystore.jks" "$ROOT/backend/.secrets/upload-keystore.jks" && found=1 || true
check_path "backend/.secrets/google-play-service-account.json" "$ROOT/backend/.secrets/google-play-service-account.json" && found=1 || true
check_path "~/.hiair-secrets/play-service-account.json" "$HOME/.hiair-secrets/play-service-account.json" && found=1 || true

echo ""
echo "==> Environment variables"
for var in ANDROID_KEYSTORE_PATH ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD; do
  if [[ -n "${!var:-}" ]]; then
    echo "SET: $var"
    found=1
  else
    echo "UNSET: $var"
  fi
done

echo ""
echo "==> Gitignored patterns (.gitignore)"
rg -n 'keystore|\.jks|\.p12|google-play-service' "$ROOT/.gitignore" || true

echo ""
echo "==> Historical signing conventions in git"
git -C "$ROOT" log --all -S 'upload-keystore' --oneline | head -3 || true
git -C "$ROOT" log --all -S 'hiair-release.keystore' --oneline | head -3 || true

echo ""
echo "==> Branches with Play publish workflow (not merged to current main)"
git -C "$ROOT" branch -a | rg 'android-play-publish|android-publishing' || true

echo ""
if [[ "$found" -eq 1 ]]; then
  echo "RESULT: signing material detected — configure build and run validate_signed_android_release.sh"
  exit 0
fi

echo "RESULT: no HiAir release keystore or Play service account found on this machine."
echo "If keystore exists in GitHub production secrets (ANDROID_KEYSTORE_BASE64), trigger .github/workflows/android-release.yml."
exit 2
