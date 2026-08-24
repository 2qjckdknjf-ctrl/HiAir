#!/usr/bin/env bash
# Create disposable local Android QA AVDs (android-34 google_apis arm64) without downloading new SDK packages.
set -euo pipefail

SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
AVD_MANAGER="${SDK}/cmdline-tools/latest/bin/avdmanager"
SYSTEM_IMAGE="system-images;android-34;google_apis;arm64-v8a"

if [[ ! -x "${AVD_MANAGER}" ]]; then
  echo "[avd] avdmanager not found at ${AVD_MANAGER}" >&2
  exit 1
fi

if ! "${SDK}/cmdline-tools/latest/bin/sdkmanager" --list_installed 2>/dev/null | grep -q "system-images;android-34;google_apis;arm64-v8a"; then
  echo "[avd] Required system image missing: ${SYSTEM_IMAGE}" >&2
  exit 1
fi

create_avd() {
  local name="$1"
  local device="$2"
  if "${AVD_MANAGER}" list avd | grep -q "Name: ${name}"; then
    echo "[avd] exists ${name}"
    return 0
  fi
  echo no | "${AVD_MANAGER}" create avd -n "${name}" -k "${SYSTEM_IMAGE}" -d "${device}" --force
  echo "[avd] created ${name} (${device})"
}

create_avd "hiair-qa-phone" "pixel_6"
create_avd "hiair-qa-tablet" "pixel_tablet"
echo "[avd] done"
