#!/bin/sh
# Shared Xcode Cloud release gates. Source this file, or invoke:
#   ios_release_gates.sh version <marketing>
#     exit 0 = ALLOW VERSION GATE (not an upload)
#     exit 1 = REJECT (marketing version <= live App Store 1.1)
#   ios_release_gates.sh start
#     uses CI_START_CONDITION / CI_TAG / CI_BRANCH
#     exit 0 = release-intent present
#     exit 1 = not a release start
# CFBundleVersion / CURRENT_PROJECT_VERSION is intentionally unused.

stale_marketing_version() {
  case "$1" in
    1.0|1.0.*|1.1|1.1.0) return 0 ;;
  esac
  return 1
}

explicit_ios_release_start() {
  case "${CI_START_CONDITION:-}" in
    manual|manual_rebuild) return 0 ;;
  esac
  if [ -n "${CI_TAG:-}" ]; then
    case "$CI_TAG" in
      ios-*|v[0-9]*|release-*) return 0 ;;
    esac
  fi
  case "${CI_BRANCH:-}" in
    release/*) return 0 ;;
  esac
  return 1
}

if [ "${0##*/}" = "ios_release_gates.sh" ]; then
  cmd="${1:-}"
  case "$cmd" in
    version)
      if [ -z "${2:-}" ]; then
        echo "usage: ios_release_gates.sh version <marketing>" >&2
        exit 2
      fi
      if stale_marketing_version "$2"; then
        exit 1
      fi
      exit 0
      ;;
    start)
      if explicit_ios_release_start; then
        exit 0
      fi
      exit 1
      ;;
    *)
      echo "usage: ios_release_gates.sh version <marketing> | start" >&2
      exit 2
      ;;
  esac
fi
