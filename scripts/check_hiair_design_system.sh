#!/usr/bin/env bash
# HiAir design system guard — warning-only by default.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WARN=0

warn() { echo "WARN: $1"; WARN=$((WARN + 1)); }

echo "== HiAir design system check =="

# Token files must exist
for f in \
  "$ROOT/mobile/ios/HiAir/DesignSystem/HiAirColors.swift" \
  "$ROOT/mobile/ios/HiAir/DesignSystem/HiAirComponents.swift" \
  "$ROOT/mobile/android/app/src/main/java/com/hiair/ui/design/HiAirColors.kt" \
  "$ROOT/mobile/android/app/src/main/java/com/hiair/ui/design/HiAirComponents.kt"
do
  [[ -f "$f" ]] || warn "Missing token/component file: $f"
done

# Forbidden pure red in screen folders
if command -v rg >/dev/null 2>&1; then
  if rg -n '#FF0000|#ff0000|Color\.red\b|0xFFFF0000' "$ROOT/mobile/ios/HiAir/Screens" "$ROOT/mobile/android/app/src/main/java/com/hiair/ui/render" 2>/dev/null; then
    warn "Forbidden pure red found in screen files"
  fi
  IOS_HITS=$(rg -n 'Color\(hex:|#[0-9A-Fa-f]{6}' "$ROOT/mobile/ios/HiAir/Screens" 2>/dev/null | wc -l | tr -d ' ')
  AND_HITS=$(rg -n 'Color\.parseColor|#[0-9A-Fa-f]{6}' "$ROOT/mobile/android/app/src/main/java/com/hiair/ui/render" 2>/dev/null | wc -l | tr -d ' ')
else
  if grep -rnE '#FF0000|#ff0000|Color\.red\b|0xFFFF0000' "$ROOT/mobile/ios/HiAir/Screens" "$ROOT/mobile/android/app/src/main/java/com/hiair/ui/render" 2>/dev/null; then
    warn "Forbidden pure red found in screen files"
  fi
  IOS_HITS=$(grep -rnE 'Color\(hex:|#[0-9A-Fa-f]{6}' "$ROOT/mobile/ios/HiAir/Screens" 2>/dev/null | wc -l | tr -d ' ')
  AND_HITS=$(grep -rnE 'Color\.parseColor|#[0-9A-Fa-f]{6}' "$ROOT/mobile/android/app/src/main/java/com/hiair/ui/render" 2>/dev/null | wc -l | tr -d ' ')
fi

if [[ "$IOS_HITS" -gt 0 ]]; then
  warn "iOS screens contain $IOS_HITS hardcoded color references (migrate to tokens)"
  if command -v rg >/dev/null 2>&1; then
    rg -n 'Color\(hex:|#[0-9A-Fa-f]{6}' "$ROOT/mobile/ios/HiAir/Screens" 2>/dev/null | head -20
  else
    grep -rnE 'Color\(hex:|#[0-9A-Fa-f]{6}' "$ROOT/mobile/ios/HiAir/Screens" 2>/dev/null | head -20
  fi
fi

# Hardcoded hex in Android renderers
if [[ "$AND_HITS" -gt 0 ]]; then
  warn "Android renderers contain $AND_HITS hardcoded color references"
  if command -v rg >/dev/null 2>&1; then
    rg -n 'Color\.parseColor|#[0-9A-Fa-f]{6}' "$ROOT/mobile/android/app/src/main/java/com/hiair/ui/render" 2>/dev/null | head -20
  else
    grep -rnE 'Color\.parseColor|#[0-9A-Fa-f]{6}' "$ROOT/mobile/android/app/src/main/java/com/hiair/ui/render" 2>/dev/null | head -20
  fi
fi

# Large PNGs in screen folders (>500KB)
while IFS= read -r png; do
  size=$(stat -f%z "$png" 2>/dev/null || stat -c%s "$png" 2>/dev/null || echo 0)
  if [[ "$size" -gt 512000 ]]; then
    warn "Large PNG in UI folder: $png ($size bytes)"
  fi
done < <(find "$ROOT/mobile/ios/HiAir/Screens" "$ROOT/mobile/android/app/src/main/java/com/hiair/ui/render" -name '*.png' 2>/dev/null)

# Brand docs
for doc in HiAir-brand-system.md HiAir-brand-assets-manifest.md HiAir-design-system-guardrails.md; do
  [[ -f "$ROOT/docs/brand/$doc" ]] || warn "Missing brand doc: docs/brand/$doc"
done

echo "== Done: $WARN warning(s) =="
exit 0
