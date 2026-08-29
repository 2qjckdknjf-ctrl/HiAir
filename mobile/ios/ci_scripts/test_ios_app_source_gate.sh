#!/bin/sh
# Local/CI check for ios_app_source_gate.sh — does not talk to App Store Connect.
set -eu
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
GATE="$DIR/ios_app_source_gate.sh"

assert_exit() {
  expected="$1"
  label="$2"
  shift 2
  set +e
  printf '%s\n' "$@" | sh "$GATE"
  actual=$?
  set -e
  if [ "$actual" -ne "$expected" ]; then
    echo "FAIL $label: expected $expected got $actual" >&2
    exit 1
  fi
  echo "PASS $label"
}

assert_exit 2 web_only 'web/index.html' 'web/sitemap.xml'
assert_exit 2 docs_only 'docs/seo/SEARCH_FOUNDATION.md'
assert_exit 2 ci_scripts_only 'mobile/ios/ci_scripts/ci_post_clone.sh' 'mobile/ios/ci_scripts/ios_app_source_gate.sh'
assert_exit 0 project_yml 'mobile/ios/project.yml'
assert_exit 0 swift_source 'web/index.html' 'mobile/ios/HiAir/HiAirApp.swift'
assert_exit 0 xcodeproj 'mobile/ios/HiAir.xcodeproj/project.pbxproj'

echo "All ios_app_source_gate checks passed."
