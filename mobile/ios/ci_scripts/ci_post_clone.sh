#!/bin/sh
# Xcode Cloud: after clone — XcodeGen + SwiftPM resolve (HiAir monorepo path).
set -eu

IOS_DIR="${CI_PRIMARY_REPOSITORY_PATH}/mobile/ios"
cd "$IOS_DIR"

echo "==> Xcode Cloud post-clone (HiAir iOS)"
echo "    CI_PRIMARY_REPOSITORY_PATH=${CI_PRIMARY_REPOSITORY_PATH}"
echo "    pwd=$(pwd)"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "==> Install XcodeGen (Homebrew)"
  brew install xcodegen
fi

echo "==> Generate HiAir.xcodeproj from project.yml"
xcodegen generate

echo "==> Resolve Swift package dependencies"
xcodebuild -resolvePackageDependencies \
  -project HiAir.xcodeproj \
  -scheme HiAir

echo "==> Post-clone done"
