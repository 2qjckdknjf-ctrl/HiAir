#!/bin/sh
# Local/CI checks for release-intent and marketing-version gates.
# Does not talk to App Store Connect and does not upload a binary.
set -eu
DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
GATES="$DIR/ios_release_gates.sh"
YML="$DIR/../project.yml"

assert_version() {
  expected="$1"
  label="$2"
  version="$3"
  set +e
  sh "$GATES" version "$version"
  actual=$?
  set -e
  if [ "$actual" -ne "$expected" ]; then
    echo "FAIL $label: expected exit $expected got $actual for $version" >&2
    exit 1
  fi
  echo "PASS $label ($version)"
}

assert_start() {
  expected="$1"
  label="$2"
  set +e
  sh "$GATES" start
  actual=$?
  set -e
  if [ "$actual" -ne "$expected" ]; then
    echo "FAIL $label: expected exit $expected got $actual (CI_START_CONDITION=${CI_START_CONDITION-} CI_TAG=${CI_TAG-} CI_BRANCH=${CI_BRANCH-})" >&2
    exit 1
  fi
  echo "PASS $label"
}

assert_version 1 reject_1.0.1 1.0.1
assert_version 1 reject_1.1 1.1
assert_version 1 reject_1.1.0 1.1.0
assert_version 1 reject_1.0 1.0
assert_version 0 allow_1.1.1 1.1.1
assert_version 0 allow_1.2 1.2
assert_version 0 allow_2.0 2.0

# CFBundleVersion / CURRENT_PROJECT_VERSION must not affect the marketing gate.
CURRENT_PROJECT_VERSION=9999 CI_BUILD_NUMBER=9999 assert_version 1 reject_1.0.1_with_high_build 1.0.1
CURRENT_PROJECT_VERSION=9999 CI_BUILD_NUMBER=9999 assert_version 0 allow_1.2_with_any_build 1.2

committed=$(sed -n 's/.*MARKETING_VERSION: *"\([^"]*\)".*/\1/p' "$YML" | head -1)
if [ "$committed" != "1.0.1" ]; then
  echo "FAIL committed MARKETING_VERSION is $committed (expected 1.0.1 on this branch)" >&2
  exit 1
fi
assert_version 1 reject_committed_project_yml "$committed"
echo "PASS project.yml MARKETING_VERSION is the CFBundleShortVersionString source ($committed)"

CI_START_CONDITION=push CI_TAG= CI_BRANCH=main assert_start 1 push_main_is_not_release
CI_START_CONDITION=pr_open CI_TAG= CI_BRANCH=seo/search-foundation assert_start 1 pr_is_not_release
CI_START_CONDITION=schedule CI_TAG= CI_BRANCH=main assert_start 1 schedule_is_not_release
CI_START_CONDITION=manual CI_TAG= CI_BRANCH=main assert_start 0 manual_is_release
CI_START_CONDITION=manual_rebuild CI_TAG= CI_BRANCH=main assert_start 0 manual_rebuild_is_release
CI_START_CONDITION=push CI_TAG=ios-1.2.0 CI_BRANCH=main assert_start 0 tag_ios_is_release
CI_START_CONDITION=push CI_TAG= CI_BRANCH=release/ios-1.2 assert_start 0 release_branch_is_release

echo "All ios_release_gates checks passed."
