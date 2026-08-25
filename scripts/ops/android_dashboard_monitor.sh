#!/usr/bin/env bash
# Reproducible Dashboard store-shot install/monitor gate for Android.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID_DIR="${ROOT}/mobile/android"
OPS="${ROOT}/scripts/ops"
OUT="${HIAIR_ANDROID_MONITOR_OUT:-${ROOT}/.evidence/android-dashboard-monitor/$(date +%Y%m%d-%H%M%S)}"
[[ "${OUT}" = /* ]] || OUT="${ROOT}/${OUT}"
AVD_NAME="${HIAIR_ANDROID_AVD:-hiair-qa-phone}"
SOURCE_SHA="$(git -C "${ROOT}" rev-parse HEAD)"
MONITOR_SECONDS="${HIAIR_ANDROID_MONITOR_SECONDS:-60}"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
ADB="${SDK}/platform-tools/adb"
EXPECTED_PACKAGE="com.hiair"
MARKER="screen.dashboard.root"
EMU_PID=""

get_foreground_package() {
  local activity_dump window_dump
  activity_dump="$("${ADB_S[@]}" shell dumpsys activity activities 2>/dev/null || true)"
  window_dump="$("${ADB_S[@]}" shell dumpsys window windows 2>/dev/null || true)"
  python3 - <<'PY' "${OPS}" "${activity_dump}" "${window_dump}"
import sys
sys.path.insert(0, sys.argv[1])
from android_capture_lib import foreground_package_from_adb_output
print(foreground_package_from_adb_output(sys.argv[2], sys.argv[3]) or "")
PY
}

mkdir -p "${OUT}"
if [[ -n "$(ls -A "${OUT}" 2>/dev/null || true)" ]]; then
  echo "[dashboard-monitor] output must be empty: ${OUT}" >&2
  exit 1
fi

cleanup() {
  [[ -n "${EMU_PID}" ]] && kill "${EMU_PID}" 2>/dev/null || true
}
trap cleanup EXIT

if [[ -n "${HIAIR_ANDROID_SERIAL:-}" ]]; then
  RESOLVE_JSON="$(bash "${OPS}/resolve_android_emulator.sh" "${AVD_NAME}" "${HIAIR_ANDROID_SERIAL}")"
else
  export HIAIR_ANDROID_EMU_LOG="${OUT}/emulator.log"
  RESOLVE_JSON="$(bash "${OPS}/resolve_android_emulator.sh" "${AVD_NAME}")"
fi
SERIAL="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['serial'])" "${RESOLVE_JSON}")"
EMU_PID="$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('emulator_pid') or '')" "${RESOLVE_JSON}")"
ADB_S=("${ADB}" -s "${SERIAL}")

cd "${ANDROID_DIR}"
export JAVA_HOME="${JAVA_HOME:-/Users/alex/Library/Java/JavaVirtualMachines/jbr-17.0.14/Contents/Home}"
./gradlew assembleDebug --quiet
APK="${ANDROID_DIR}/app/build/outputs/apk/debug/app-debug.apk"
APK_SHA="$(python3 -c "import hashlib; print(hashlib.sha256(open('${APK}','rb').read()).hexdigest())")"
printf '%s\n' "${SOURCE_SHA}" > "${OUT}/source_sha.txt"
printf '%s\n' "${APK_SHA}" > "${OUT}/apk_sha256.txt"

if ! "${ADB_S[@]}" install -r "${APK}" >"${OUT}/install.log" 2>&1; then
  echo "[dashboard-monitor] adb install failed; see install.log" >&2
  exit 1
fi

run_cycle() {
  local name="$1"
  local cycle_dir="${OUT}/${name}"
  mkdir -p "${cycle_dir}"
  "${ADB_S[@]}" shell pm clear com.hiair >/dev/null 2>&1 || true
  "${ADB_S[@]}" logcat -c >/dev/null 2>&1 || true
  local start_out pid fg_pkg stamp
  stamp="$("${ADB_S[@]}" shell date +%s 2>/dev/null | tr -d '\r')"
  start_out="$("${ADB_S[@]}" shell am start -W -n com.hiair/.AppMainActivity \
    -e HIAIR_STORE_SHOTS 1 -e HIAIR_SCREEN dashboard -e HIAIR_SHOT_LANGUAGE en 2>&1)" || true
  printf '%s\n' "${start_out}" > "${cycle_dir}/launch.txt"
  grep -q "Status: ok" "${cycle_dir}/launch.txt" || { echo "[dashboard-monitor] launch failed ${name}" >&2; return 1; }

  pid=""
  for _ in $(seq 1 40); do
    pid="$("${ADB_S[@]}" shell pidof com.hiair 2>/dev/null | tr -d '\r' || true)"
    [[ -n "${pid}" ]] && break
    sleep 0.5
  done
  [[ -n "${pid}" ]] || { echo "[dashboard-monitor] missing pid ${name}" >&2; return 1; }
  printf '%s\n' "${pid}" > "${cycle_dir}/pid.txt"

  fg_pkg="$(get_foreground_package)"
  printf '%s\n' "${fg_pkg}" > "${cycle_dir}/foreground_package.txt"
  [[ "${fg_pkg}" == "${EXPECTED_PACKAGE}" ]] || return 1

  "${ADB_S[@]}" shell uiautomator dump /sdcard/window_dump.xml >/dev/null
  "${ADB_S[@]}" pull /sdcard/window_dump.xml "${cycle_dir}/hierarchy.xml" >/dev/null
  "${ADB_S[@]}" exec-out screencap -p > "${cycle_dir}/screenshot.png"
  "${ADB_S[@]}" shell logcat -d -t "${stamp}" > "${cycle_dir}/logcat.txt" 2>/dev/null || true
  grep -q "FATAL EXCEPTION" "${cycle_dir}/logcat.txt" && return 1
  python3 "${OPS}/android_capture_validate_cli.py" "${cycle_dir}/hierarchy.xml" "${MARKER}" "${fg_pkg}" >/dev/null

  if [[ "${name}" == "initial-60s" ]]; then
    for i in $(seq 1 "${MONITOR_SECONDS}"); do
      sleep 1
      pid="$("${ADB_S[@]}" shell pidof com.hiair 2>/dev/null | tr -d '\r' || true)"
      [[ -n "${pid}" ]] || { echo "[dashboard-monitor] pid lost at t=${i}s" >&2; return 1; }
    done
    printf 'alive_%ss\n' "${MONITOR_SECONDS}" > "${cycle_dir}/monitor.txt"
  fi

  if [[ "${name}" == "background-foreground" ]]; then
    "${ADB_S[@]}" shell input keyevent KEYCODE_HOME >/dev/null
    sleep 2
    "${ADB_S[@]}" shell am start -n com.hiair/.AppMainActivity >/dev/null
    sleep 2
    pid="$("${ADB_S[@]}" shell pidof com.hiair 2>/dev/null | tr -d '\r' || true)"
    [[ -n "${pid}" ]] || return 1
  fi

  if [[ "${name}" == "recreate" ]]; then
    "${ADB_S[@]}" shell am start -n com.hiair/.AppMainActivity >/dev/null
    sleep 2
  fi

  echo "[dashboard-monitor] PASS ${name} pid=${pid} fg=${fg_pkg}"
}

run_cycle "initial-60s"
"${ADB_S[@]}" shell am force-stop com.hiair
run_cycle "force-stop-relaunch"
run_cycle "background-foreground"
run_cycle "recreate"
run_cycle "sequential-1"
run_cycle "sequential-2"
run_cycle "sequential-3"

python3 - <<PY "${OUT}" "${SOURCE_SHA}" "${APK_SHA}" "${SERIAL}" "${AVD_NAME}"
import json, sys
from datetime import datetime, timezone
out, source_sha, apk_sha, serial, avd = sys.argv[1:]
payload = {
    "gate": "android_dashboard_install_monitor",
    "status": "PASS",
    "captured_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "source_sha": source_sha,
    "apk_sha256": apk_sha,
    "serial": serial,
    "avd_name": avd,
    "cycles": ["initial-60s", "force-stop-relaunch", "background-foreground", "recreate", "sequential-1", "sequential-2", "sequential-3"],
}
with open(f"{out}/monitor-manifest.json", "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY

trap - EXIT
cleanup
echo "[dashboard-monitor] done → ${OUT}"
