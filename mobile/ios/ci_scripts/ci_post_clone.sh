#!/bin/sh
# Xcode Cloud: refuse Archive / App Store upload unless this is an explicit
# iOS release AND iOS app source changed AND marketing version is > live 1.1.
# Then ensure HiAir.xcodeproj includes all Swift sources and resolve SPM.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
GATE="$SCRIPT_DIR/ios_app_source_gate.sh"
# shellcheck source=ios_release_gates.sh
. "$SCRIPT_DIR/ios_release_gates.sh"
REPO="${CI_PRIMARY_REPOSITORY_PATH:-}"
if [ -z "$REPO" ]; then
  REPO=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
fi

# Live App Store CFBundleShortVersionString confirmed via iTunes lookup id=6773610034.
# 1.0.1 and 1.1 must never be uploaded again. Raising CFBundleVersion alone does not
# satisfy ITMS-90478 / ITMS-90186 / ITMS-90062.

collect_changed_paths() {
  cd "$REPO"
  if [ -n "${CI_PULL_REQUEST_TARGET_COMMIT:-}" ] && [ -n "${CI_COMMIT:-}" ]; then
    git fetch --depth=50 origin "${CI_PULL_REQUEST_TARGET_COMMIT}" >/dev/null 2>&1 || true
    if git cat-file -e "${CI_PULL_REQUEST_TARGET_COMMIT}^{commit}" 2>/dev/null; then
      git diff --name-only "${CI_PULL_REQUEST_TARGET_COMMIT}" "${CI_COMMIT}"
      return
    fi
  fi
  if ! git rev-parse --verify HEAD^ >/dev/null 2>&1; then
    git fetch --deepen=20 >/dev/null 2>&1 || true
  fi
  if git rev-parse --verify HEAD^2 >/dev/null 2>&1; then
    git diff --name-only HEAD^1 HEAD
  elif git rev-parse --verify HEAD^ >/dev/null 2>&1; then
    git diff --name-only HEAD^ HEAD
  else
    echo "XCODE_CLOUD_SKIP: cannot determine changed paths (shallow clone without parent)."
    return 1
  fi
}

echo "==> Xcode Cloud post-clone gate"
echo "    CI_WORKFLOW=${CI_WORKFLOW:-unset}"
echo "    CI_BRANCH=${CI_BRANCH:-unset}"
echo "    CI_TAG=${CI_TAG:-unset}"
echo "    CI_START_CONDITION=${CI_START_CONDITION:-unset}"
echo "    CI_XCODEBUILD_ACTION=${CI_XCODEBUILD_ACTION:-unset}"
echo "    CI_PULL_REQUEST_NUMBER=${CI_PULL_REQUEST_NUMBER:-unset}"

if ! explicit_ios_release_start; then
  echo "XCODE_CLOUD_SKIP: automatic Archive is not an iOS release start."
  echo "Allowed starts: Manual, tag ios-* / v* / release-*, or branch release/*."
  echo "Web/docs/SEO pushes must not upload to App Store Connect."
  echo "Use GitHub Actions workflow ios-ci.yml for compile/test validation."
  exit 1
fi

CHANGED=$(collect_changed_paths) || {
  echo "Refusing Archive because the change set could not be proven."
  exit 1
}
echo "==> Changed paths in this Xcode Cloud checkout:"
echo "$CHANGED" | sed 's/^/    /'

if ! printf '%s\n' "$CHANGED" | sh "$GATE"; then
  echo "XCODE_CLOUD_SKIP: no iOS app source in this commit."
  echo "Refusing Archive / App Store Connect upload for web, docs, or ci_scripts-only changes."
  exit 1
fi

MARKETING_VERSION=$(sed -n 's/.*MARKETING_VERSION: *"\([^"]*\)".*/\1/p' "${REPO}/mobile/ios/project.yml" | head -1)
echo "==> MARKETING_VERSION=${MARKETING_VERSION:-unset}"
if [ -z "$MARKETING_VERSION" ] || stale_marketing_version "$MARKETING_VERSION"; then
  echo "XCODE_CLOUD_SKIP: CFBundleShortVersionString ${MARKETING_VERSION:-empty} is not greater than live App Store 1.1."
  echo "Do not upload. Next intentional iOS marketing version must be > 1.1 (project next train: 1.2)."
  echo "Increasing CFBundleVersion / CURRENT_PROJECT_VERSION alone does not fix ITMS-90478."
  exit 1
fi

IOS_DIR="${REPO}/mobile/ios"
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

if ! grep -q 'com.apple.developer.healthkit' HiAir/HiAir.entitlements 2>/dev/null; then
  echo "error: com.apple.developer.healthkit missing from HiAir.entitlements after XcodeGen." >&2
  exit 1
fi

if ! test -f HiAir/PrivacyInfo.xcprivacy; then
  echo "error: HiAir/PrivacyInfo.xcprivacy missing (App Store privacy manifest required)." >&2
  exit 1
fi

echo "==> Resolve Swift package dependencies"
xcodebuild -resolvePackageDependencies \
  -project HiAir.xcodeproj \
  -scheme HiAir

echo "==> Post-clone done"
