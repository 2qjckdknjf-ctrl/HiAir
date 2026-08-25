#!/usr/bin/env bash
# Resolve a deterministic Android emulator serial for capture runs.
set -euo pipefail

SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
ADB="${SDK}/platform-tools/adb"
EMULATOR="${SDK}/emulator/emulator"

AVD_NAME="${1:?avd name required}"
REQUESTED_SERIAL="${2:-}"
REQUESTED_PORT="${3:-}"

is_emulator_serial() {
  [[ "${1}" == emulator-* ]]
}

is_physical_serial() {
  local serial="$1"
  [[ -n "${serial}" && "${serial}" != emulator-* ]]
}

device_state() {
  "${ADB}" -s "$1" get-state 2>/dev/null | tr -d '\r' || echo "missing"
}

avd_for_serial() {
  local serial="$1"
  if ! is_emulator_serial "${serial}"; then
    echo ""
    return 0
  fi
  "${ADB}" -s "${serial}" emu avd name 2>/dev/null | head -1 | tr -d '\r' || true
}

pick_free_port() {
  local port="${REQUESTED_PORT}"
  if [[ -n "${port}" ]]; then
    echo "${port}"
    return 0
  fi
  local candidate
  for candidate in $(seq 5554 2 5598); do
    if ! nc -z localhost "${candidate}" >/dev/null 2>&1; then
      echo "${candidate}"
      return 0
    fi
  done
  echo "[resolve-android-emulator] no free emulator port in 5554-5598" >&2
  return 1
}

if [[ -n "${REQUESTED_SERIAL}" ]]; then
  SERIAL="${REQUESTED_SERIAL}"
  STATE="$(device_state "${SERIAL}")"
  if [[ "${STATE}" != "device" ]]; then
    echo "[resolve-android-emulator] FAIL / DEVICE OFFLINE serial=${SERIAL} state=${STATE}" >&2
    exit 2
  fi
  if is_physical_serial "${SERIAL}"; then
    echo "[resolve-android-emulator] refusing physical device serial=${SERIAL}" >&2
    exit 3
  fi
  ACTUAL_AVD="$(avd_for_serial "${SERIAL}")"
  if [[ -n "${ACTUAL_AVD}" && "${ACTUAL_AVD}" != "${AVD_NAME}" ]]; then
    echo "[resolve-android-emulator] serial ${SERIAL} is AVD '${ACTUAL_AVD}', expected '${AVD_NAME}'" >&2
    exit 4
  fi
  EMU_PID=""
  EMU_PORT="${SERIAL#emulator-}"
else
  PORT="$(pick_free_port)"
  SERIAL="emulator-${PORT}"
  EMU_LOG="${HIAIR_ANDROID_EMU_LOG:-/tmp/hiair-emulator-${AVD_NAME}-${PORT}.log}"
  nohup "${EMULATOR}" -avd "${AVD_NAME}" -port "${PORT}" -no-snapshot-save -no-boot-anim -gpu swiftshader_indirect \
    >"${EMU_LOG}" 2>&1 &
  EMU_PID=$!
  EMU_PORT="${PORT}"
  for _ in $(seq 1 180); do
    STATE="$(device_state "${SERIAL}")"
    [[ "${STATE}" == "device" ]] && break
    sleep 2
  done
  STATE="$(device_state "${SERIAL}")"
  if [[ "${STATE}" != "device" ]]; then
    echo "[resolve-android-emulator] FAIL / DEVICE OFFLINE serial=${SERIAL} state=${STATE}" >&2
    kill "${EMU_PID}" 2>/dev/null || true
    exit 2
  fi
fi

BOOT=""
for _ in $(seq 1 120); do
  BOOT="$("${ADB}" -s "${SERIAL}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  [[ "${BOOT}" == "1" ]] && break
  sleep 2
done
if [[ "${BOOT}" != "1" ]]; then
  echo "[resolve-android-emulator] boot incomplete serial=${SERIAL}" >&2
  [[ -n "${EMU_PID}" ]] && kill "${EMU_PID}" 2>/dev/null || true
  exit 5
fi

ACTUAL_AVD="$(avd_for_serial "${SERIAL}")"
if [[ -n "${ACTUAL_AVD}" && "${ACTUAL_AVD}" != "${AVD_NAME}" ]]; then
  echo "[resolve-android-emulator] AVD mismatch actual='${ACTUAL_AVD}' expected='${AVD_NAME}'" >&2
  [[ -n "${EMU_PID}" ]] && kill "${EMU_PID}" 2>/dev/null || true
  exit 4
fi

python3 - <<'PY' "${SERIAL}" "${AVD_NAME}" "${EMU_PORT}" "${EMU_PID}" "${BOOT}"
import json, sys
serial, avd, port, emu_pid, boot = sys.argv[1:]
print(json.dumps({
    "serial": serial,
    "avd_name": avd,
    "emulator_port": int(port),
    "emulator_pid": int(emu_pid) if emu_pid else None,
    "boot_completed": boot == "1",
}))
PY
