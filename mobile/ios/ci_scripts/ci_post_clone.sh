#!/bin/sh
# Xcode Cloud: ensure HiAir.xcodeproj includes all Swift sources, then resolve SPM.
set -eu

IOS_DIR="${CI_PRIMARY_REPOSITORY_PATH}/mobile/ios"
cd "$IOS_DIR"
PBX="HiAir.xcodeproj/project.pbxproj"

echo "==> Xcode Cloud post-clone (HiAir iOS)"
echo "    CI_PRIMARY_REPOSITORY_PATH=${CI_PRIMARY_REPOSITORY_PATH}"
echo "    pwd=$(pwd)"

project_includes_v2_theme() {
  grep -q 'HiAirV2Theme.swift in Sources' "$PBX" 2>/dev/null
}

install_xcodegen() {
  if command -v xcodegen >/dev/null 2>&1; then
    echo "==> XcodeGen: $(xcodegen --version)"
    return 0
  fi

  echo "==> Install XcodeGen (GitHub release, no brew)"
  GEN_VERSION="${XCODEGEN_VERSION:-2.42.0}"
  GEN_ROOT="${TMPDIR:-/tmp}/hiair-xcodegen"
  rm -rf "$GEN_ROOT"
  mkdir -p "$GEN_ROOT"
  curl -fsSL \
    "https://github.com/yonaskolb/XcodeGen/releases/download/${GEN_VERSION}/xcodegen.zip" \
    -o "$GEN_ROOT/xcodegen.zip"
  unzip -q "$GEN_ROOT/xcodegen.zip" -d "$GEN_ROOT"
  export PATH="$GEN_ROOT/xcodegen/bin:$PATH"
  echo "==> XcodeGen: $(xcodegen --version)"
}

regenerate_project() {
  install_xcodegen
  echo "==> Generate HiAir.xcodeproj from project.yml"
  xcodegen generate
}

echo "==> Regenerate Xcode project (picks up new Swift files)"
regenerate_project

if ! project_includes_v2_theme; then
  echo "error: HiAirV2Theme.swift is still not in Compile Sources after XcodeGen." >&2
  echo "  Commit an updated mobile/ios/HiAir.xcodeproj on main or fix project.yml." >&2
  exit 1
fi

if ! grep -q 'HealthKitService.swift in Sources' "$PBX" 2>/dev/null; then
  echo "error: HealthKitService.swift missing from Compile Sources after XcodeGen." >&2
  exit 1
fi

if ! grep -q 'INFOPLIST_KEY_NSHealthShareUsageDescription' "$PBX" 2>/dev/null; then
  echo "error: NSHealthShareUsageDescription missing from generated project." >&2
  exit 1
fi

echo "==> Resolve Swift package dependencies"
xcodebuild -resolvePackageDependencies \
  -project HiAir.xcodeproj \
  -scheme HiAir

echo "==> Post-clone done"
