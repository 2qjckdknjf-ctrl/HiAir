#!/usr/bin/env bash
# Generate RC artifact manifest with RC_SOURCE_SHA vs MANIFEST_COMMIT_SHA separation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

RC_ID="${RC_ID:-rc-$(date +%Y-%m-%d)}"
EVIDENCE_DIR="${EVIDENCE_DIR:-$ROOT/docs/release/artifacts/$RC_ID}"
RC_SOURCE_SHA="${RC_SOURCE_SHA:-$(git rev-parse HEAD)}"
MANIFEST_COMMIT_SHA="$(git rev-parse HEAD)"
DIRTY="$(git status --porcelain | wc -l | tr -d ' ')"

if [[ "$DIRTY" != "0" ]]; then
  echo "error: working tree not clean ($DIRTY paths). Commit first and set RC_SOURCE_SHA." >&2
  exit 1
fi

if ! git diff --quiet "$RC_SOURCE_SHA" HEAD 2>/dev/null; then
  if [[ "$RC_SOURCE_SHA" != "$MANIFEST_COMMIT_SHA" ]]; then
    echo "error: RC_SOURCE_SHA ($RC_SOURCE_SHA) != HEAD ($MANIFEST_COMMIT_SHA)" >&2
    exit 1
  fi
fi

mkdir -p "$EVIDENCE_DIR"

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

copy_with_checksum() {
  local label="$1"
  local src="$2"
  local dest_name="$3"
  if [[ ! -e "$src" ]]; then
    echo "error: missing artifact for $label: $src" >&2
    return 1
  fi
  local dest="$EVIDENCE_DIR/$dest_name"
  cp -R "$src" "$dest"
  local digest=""
  if [[ -d "$dest" ]]; then
    local zip_path="$EVIDENCE_DIR/${dest_name}.zip"
    (cd "$EVIDENCE_DIR" && ditto -c -k --sequesterRsrc --keepParent "$dest_name" "$(basename "$zip_path")")
    digest="$(sha256_file "$zip_path")"
    echo "| $label | \`$dest_name.zip\` | $(stat -f%z "$zip_path" 2>/dev/null || stat -c%s "$zip_path") | \`$digest\` |" >> "$EVIDENCE_DIR/MANIFEST.md.tmp"
  else
    digest="$(sha256_file "$dest")"
    echo "| $label | \`$dest_name\` | $(stat -f%z "$dest" 2>/dev/null || stat -c%s "$dest") | \`$digest\` |" >> "$EVIDENCE_DIR/MANIFEST.md.tmp"
  fi
}

IOS_APP="${IOS_APP:-}"
ANDROID_AAB="${ANDROID_AAB:-$ROOT/mobile/android/app/build/outputs/bundle/release/app-release.aab}"

if [[ -z "$IOS_APP" ]]; then
  for candidate in \
    "$ROOT/mobile/ios/build/HiAir-iphonesimulator.app" \
    "$HOME/Library/Developer/Xcode/DerivedData"/HiAir-*/Build/Products/Debug-iphonesimulator/HiAir.app; do
    if [[ -d "$candidate" ]]; then
      IOS_APP="$candidate"
      break
    fi
  done
fi

cat > "$EVIDENCE_DIR/MANIFEST.md" <<EOF
# Release artifact manifest — $RC_ID

**Status:** local RC evidence (unsigned / simulator unless noted).

| Field | Value |
|-------|-------|
| RC_SOURCE_SHA | \`$RC_SOURCE_SHA\` |
| MANIFEST_COMMIT_SHA | \`$MANIFEST_COMMIT_SHA\` |
| Branch | \`$(git branch --show-current)\` |
| Generated (UTC) | $(date -u +%Y-%m-%dT%H:%M:%SZ) |

> Artifacts are built from **RC_SOURCE_SHA**. If MANIFEST_COMMIT_SHA differs, only manifest metadata changed after the build.

## Artifacts

| Artifact | File | Size (bytes) | SHA-256 |
|---|---|---:|---|
EOF

: > "$EVIDENCE_DIR/MANIFEST.md.tmp"

if [[ -n "$IOS_APP" && -d "$IOS_APP" ]]; then
  copy_with_checksum "iOS simulator .app" "$IOS_APP" "HiAir-iphonesimulator.app"
fi

if [[ -f "$ANDROID_AAB" ]]; then
  cp "$ANDROID_AAB" "$EVIDENCE_DIR/app-release.aab"
  digest="$(sha256_file "$EVIDENCE_DIR/app-release.aab")"
  size="$(stat -f%z "$EVIDENCE_DIR/app-release.aab" 2>/dev/null || stat -c%s "$EVIDENCE_DIR/app-release.aab")"
  echo "| Android release AAB | \`app-release.aab\` | $size | \`$digest\` |" >> "$EVIDENCE_DIR/MANIFEST.md.tmp"
fi

cat "$EVIDENCE_DIR/MANIFEST.md.tmp" >> "$EVIDENCE_DIR/MANIFEST.md"
rm -f "$EVIDENCE_DIR/MANIFEST.md.tmp"

echo "Manifest written: $EVIDENCE_DIR/MANIFEST.md"
