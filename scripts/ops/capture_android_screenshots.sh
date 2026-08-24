#!/usr/bin/env bash
# Capture Android store screenshots with deterministic emulator serial and semantic validation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID_DIR="${ROOT}/mobile/android"
OPS="${ROOT}/scripts/ops"
OUT="${HIAIR_ANDROID_SHOT_OUT:-${ROOT}/.evidence/android-screenshots/$(date +%Y%m%d-%H%M%S)}"
[[ "${OUT}" = /* ]] || OUT="${ROOT}/${OUT}"
AVD_NAME="${HIAIR_ANDROID_AVD:-hiair-qa-phone}"
LANGUAGE="${HIAIR_SHOT_LANGUAGE:-en}"
FONT_SCALE="${HIAIR_ANDROID_FONT_SCALE:-1.0}"
REDUCE_MOTION="${HIAIR_ANDROID_REDUCE_MOTION:-0}"
RUN_ID="${HIAIR_CAPTURE_RUN_ID:-$(date +%s)}"
DEVICE_CAPTURE_OUT="/sdcard/Download/hiair-capture-${RUN_ID}"
MANIFEST="${OUT}/capture-manifest.json"
SCREENS_JSON="${OUT}/screens-partial.json"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
ADB="${SDK}/platform-tools/adb"
SOURCE_SHA="$(git -C "${ROOT}" rev-parse HEAD)"
EXPECTED_PACKAGE="com.hiair"

SCREENS=(
  "dashboard:01-dashboard.png:screen.dashboard.root"
  "planner:02-planner.png:screen.planner.root"
  "insights:03-insights.png:screen.insights.root"
  "symptoms:04-symptoms.png:screen.symptoms.root"
  "settings:05-settings.png:screen.settings.root"
  "paywall:06-paywall.png:screen.paywall.root"
  "onboarding:07-onboarding.png:screen.onboarding.root"
  "navigation:08-navigation-shell.png:screen.navigation.root"
)

EMU_PID=""
SERIAL=""
FAILURE_REASON=""
RUN_STATUS="PASS"

if [[ -e "${OUT}" ]] && [[ -n "$(ls -A "${OUT}" 2>/dev/null || true)" ]]; then
  echo "[android-shots] output directory must be empty: ${OUT}" >&2
  exit 1
fi
mkdir -p "${OUT}"
echo '[]' > "${SCREENS_JSON}"

write_failure_manifest() {
  local reason="${1:-${FAILURE_REASON:-unknown failure}}"
  python3 - <<'PY' "${MANIFEST}" "${OUT}" "${ROOT}" "${RUN_ID}" "${SOURCE_SHA}" "${SCREENS_JSON}" "${reason}" \
    "${AVD_NAME}" "${SERIAL}" "${LANGUAGE}" "${FONT_SCALE}" "${REDUCE_MOTION}"
import json, subprocess, sys
from pathlib import Path

manifest_path, out_dir, root, run_id, source_sha, screens_json, reason, avd, serial, lang, font_scale, motion = sys.argv[1:13]
sys.path.insert(0, str(Path(root) / "scripts" / "ops"))
from android_capture_lib import build_manifest, write_manifest
source_tree = json.loads(subprocess.check_output(["python3", str(Path(root)/"scripts/ops/provenance_source_tree.py"), root, "--json"], text=True))
screens = json.loads(Path(screens_json).read_text(encoding="utf-8"))
requested = {
    "captureRunId": run_id,
    "language": lang,
    "fontScale": float(font_scale),
    "reduceMotion": motion == "1",
    "avdName": avd,
    "serial": serial,
    "sourceSha": source_sha,
}
payload = build_manifest(
    out_dir=Path(out_dir),
    source_tree=source_tree,
    source_sha=source_sha,
    run_id=run_id,
    requested=requested,
    observed={},
    screens=screens,
    test_configuration={"avd_name": avd, "serial": serial, "language": lang},
    capture_completed=False,
    semantic_capture_ok=False,
    failure_reason=reason,
)
write_manifest(Path(manifest_path), payload)
print(manifest_path)
PY
}

cleanup_emulator() {
  if [[ -n "${EMU_PID}" ]]; then
    kill "${EMU_PID}" 2>/dev/null || true
    wait "${EMU_PID}" 2>/dev/null || true
  fi
}

on_exit() {
  local code=$?
  if [[ "${code}" -ne 0 || "${RUN_STATUS}" != "PASS" ]]; then
    write_failure_manifest "${FAILURE_REASON:-capture failed with exit ${code}}"
  fi
  cleanup_emulator
}
trap on_exit EXIT

if [[ "${HIAIR_ANDROID_ALLOW_REUSE:-0}" == "1" ]]; then
  if [[ -z "${HIAIR_ANDROID_SERIAL:-}" ]]; then
    echo "[android-shots] reuse mode requires HIAIR_ANDROID_SERIAL" >&2
    exit 1
  fi
  RESOLVE_JSON="$(bash "${OPS}/resolve_android_emulator.sh" "${AVD_NAME}" "${HIAIR_ANDROID_SERIAL}")"
else
  if "${ADB}" devices | awk 'NR>1 && $2=="device"{found=1} END{exit found?0:1}'; then
    echo "[android-shots] booted device(s) present; refusing implicit reuse" >&2
    exit 1
  fi
  EMU_LOG="${OUT}/emulator.log"
  export HIAIR_ANDROID_EMU_LOG="${EMU_LOG}"
  RESOLVE_JSON="$(bash "${OPS}/resolve_android_emulator.sh" "${AVD_NAME}")"
fi

SERIAL="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['serial'])" "${RESOLVE_JSON}")"
EMU_PID="$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('emulator_pid') or '')" "${RESOLVE_JSON}")"
EMU_PORT="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['emulator_port'])" "${RESOLVE_JSON}")"
echo "[android-shots] serial=${SERIAL} avd=${AVD_NAME} port=${EMU_PORT}"

ADB_S=("${ADB}" -s "${SERIAL}")
STATE="$("${ADB_S[@]}" get-state 2>/dev/null | tr -d '\r' || echo missing)"
if [[ "${STATE}" != "device" ]]; then
  FAILURE_REASON="FAIL / DEVICE OFFLINE serial=${SERIAL} state=${STATE}"
  echo "[android-shots] ${FAILURE_REASON}" >&2
  exit 2
fi

"${ADB_S[@]}" shell "settings put system system_locales ${LANGUAGE}" >/dev/null 2>&1 || true
"${ADB_S[@]}" shell "settings put system font_scale ${FONT_SCALE}" >/dev/null 2>&1 || true
if [[ "${REDUCE_MOTION}" == "1" ]]; then
  "${ADB_S[@]}" shell settings put global animator_duration_scale 0 >/dev/null 2>&1 || true
  "${ADB_S[@]}" shell settings put global transition_animation_scale 0 >/dev/null 2>&1 || true
fi

cd "${ANDROID_DIR}"
export JAVA_HOME="${JAVA_HOME:-/Users/alex/Library/Java/JavaVirtualMachines/jbr-17.0.14/Contents/Home}"
./gradlew assembleDebug --quiet
APK="${ANDROID_DIR}/app/build/outputs/apk/debug/app-debug.apk"
[[ -f "${APK}" ]] || { FAILURE_REASON="missing debug APK"; exit 1; }
APK_SHA="$(python3 -c "import hashlib; print(hashlib.sha256(open('${APK}','rb').read()).hexdigest())")"
echo "${APK_SHA}" > "${OUT}/apk.sha256"

if ! "${ADB_S[@]}" install -r "${APK}" >"${OUT}/install.log" 2>&1; then
  FAILURE_REASON="adb install failed; see install.log"
  exit 1
fi
"${ADB_S[@]}" shell pm clear com.hiair >/dev/null 2>&1 || true
"${ADB_S[@]}" shell mkdir -p "${DEVICE_CAPTURE_OUT}" >/dev/null

REQUESTED_ENV="${OUT}/requested-environment.json"
python3 - <<'PY' "${REQUESTED_ENV}" "${RUN_ID}" "${LANGUAGE}" "${FONT_SCALE}" "${REDUCE_MOTION}" "${AVD_NAME}" "${SERIAL}" "${SOURCE_SHA}" "${APK_SHA}"
import json, sys
path, run_id, lang, font_scale, motion, avd, serial, sha, apk_sha = sys.argv[1:]
payload = {
    "captureRunId": run_id,
    "language": lang,
    "fontScale": float(font_scale),
    "reduceMotion": motion == "1",
    "avdName": avd,
    "serial": serial,
    "sourceSha": sha,
    "apkSha256": apk_sha,
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY

AVD_INFO="$("${ADB_S[@]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || echo unknown)"
API_LEVEL="$("${ADB_S[@]}" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r' || echo unknown)"
WIDTH="$("${ADB_S[@]}" shell wm size | awk -F'[: x]+' '/Physical size/{print $2}')"
HEIGHT="$("${ADB_S[@]}" shell wm size | awk -F'[: x]+' '/Physical size/{print $3}')"
DENSITY="$("${ADB_S[@]}" shell getprop ro.sf.lcd_density 2>/dev/null | tr -d '\r' || echo unknown)"

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

capture_screen() {
  local screen="$1" filename="$2" marker="$3"
  local png="${OUT}/${filename}"
  local xml="${OUT}/${filename%.png}.xml"
  local log="${OUT}/${filename%.png}.logcat.txt"
  local launch="${OUT}/${filename%.png}.launch.txt"
  local stamp pid fg_pkg validation_json detected_marker errors fatal

  stamp="$("${ADB_S[@]}" shell date +%s 2>/dev/null | tr -d '\r')"
  "${ADB_S[@]}" logcat -c >/dev/null 2>&1 || true
  "${ADB_S[@]}" shell am force-stop com.hiair >/dev/null 2>&1 || true
  sleep 1

  start_out="$("${ADB_S[@]}" shell am start -W -n com.hiair/.AppMainActivity \
    -e HIAIR_STORE_SHOTS 1 \
    -e HIAIR_SCREEN "${screen}" \
    -e HIAIR_SHOT_LANGUAGE "${LANGUAGE}" \
    -e HIAIR_CAPTURE_RUN_ID "${RUN_ID}" \
    -e HIAIR_CAPTURE_OUT "${DEVICE_CAPTURE_OUT}" 2>&1)" || true
  printf '%s\n' "${start_out}" > "${launch}"

  if ! grep -q "Status: ok" <<<"${start_out}"; then
    FAILURE_REASON="launch failed screen=${screen}"
    echo "[android-shots] ${FAILURE_REASON}: ${start_out}" >&2
    return 1
  fi

  pid=""
  for _ in $(seq 1 80); do
    pid="$("${ADB_S[@]}" shell pidof com.hiair 2>/dev/null | tr -d '\r' || true)"
    [[ -n "${pid}" ]] && break
    sleep 0.5
  done
  if [[ -z "${pid}" ]]; then
    FAILURE_REASON="process missing screen=${screen}"
    echo "[android-shots] ${FAILURE_REASON}" >&2
    return 1
  fi

  fg_pkg=""
  for _ in $(seq 1 40); do
    fg_pkg="$(get_foreground_package)"
    [[ "${fg_pkg}" == "${EXPECTED_PACKAGE}" ]] && break
    sleep 0.25
  done
  if [[ "${fg_pkg}" != "${EXPECTED_PACKAGE}" ]]; then
    FAILURE_REASON="foreground package mismatch screen=${screen} got=${fg_pkg}"
    echo "[android-shots] ${FAILURE_REASON}" >&2
    return 1
  fi

  for _ in $(seq 1 60); do
    if "${ADB_S[@]}" shell uiautomator dump /sdcard/window_dump.xml >/dev/null 2>&1; then
      if "${ADB_S[@]}" shell grep -q "${marker}" /sdcard/window_dump.xml 2>/dev/null; then break; fi
    fi
    sleep 0.25
  done

  "${ADB_S[@]}" shell uiautomator dump /sdcard/window_dump.xml >/dev/null
  "${ADB_S[@]}" pull /sdcard/window_dump.xml "${xml}" >/dev/null
  "${ADB_S[@]}" exec-out screencap -p > "${png}"
  "${ADB_S[@]}" shell logcat -d -t "${stamp}" > "${log}" 2>/dev/null || true

  if grep -q "FATAL EXCEPTION" "${log}"; then
    FAILURE_REASON="FATAL EXCEPTION in logcat screen=${screen}"
    echo "[android-shots] ${FAILURE_REASON}" >&2
    return 1
  fi

  if ! python3 "${OPS}/android_capture_validate_cli.py" "${xml}" "${marker}" "${fg_pkg}" >/dev/null 2>"${OUT}/${filename%.png}.validate.err"; then
    FAILURE_REASON="semantic validation failed screen=${screen}"
    cat "${OUT}/${filename%.png}.validate.err" >&2 || true
    return 1
  fi

  validation_json="$(python3 - <<'PY' "${OPS}" "${xml}" "${marker}" "${fg_pkg}"
import json, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from android_capture_validate import validate_hierarchy
xml_path, marker, fg = sys.argv[2], sys.argv[3], sys.argv[4]
with open(xml_path, encoding="utf-8") as handle:
    xml_text = handle.read()
result = validate_hierarchy(xml_text, expected_marker=marker, foreground_package=fg)
print(json.dumps(result.to_dict()))
PY
)"

  python3 - <<'PY' "${SCREENS_JSON}" "${screen}" "${filename}" "${marker}" "${fg_pkg}" "${pid}" "${launch}" \
    "${xml}" "${log}" "${png}" "${validation_json}"
import hashlib, json, sys
from pathlib import Path
screens_path, screen, filename, marker, fg, pid, launch, xml, log, png, validation_json = sys.argv[1:]
screens = json.loads(Path(screens_path).read_text(encoding="utf-8"))
validation = json.loads(validation_json)
entry = {
    "filename": filename,
    "expected_screen": screen,
    "expected_marker": marker,
    "detected_marker": validation.get("detected_marker"),
    "foreground_package": fg,
    "pid": pid,
    "launch_result": Path(launch).read_text(encoding="utf-8").strip(),
    "semantic_validation_ok": validation.get("semantic_validation_ok", False),
    "validation_errors": validation.get("errors", []),
    "hierarchy_xml_path": xml,
    "hierarchy_xml_sha256": hashlib.sha256(Path(xml).read_bytes()).hexdigest(),
    "logcat_path": log,
    "logcat_sha256": hashlib.sha256(Path(log).read_bytes()).hexdigest(),
    "png_path": png,
    "png_sha256": hashlib.sha256(Path(png).read_bytes()).hexdigest(),
    "visual_review_result": "PENDING",
}
screens.append(entry)
Path(screens_path).write_text(json.dumps(screens, indent=2) + "\n", encoding="utf-8")
PY

  echo "[android-shots] OK ${screen} → ${filename} pid=${pid} fg=${fg_pkg}"
}

for entry in "${SCREENS[@]}"; do
  IFS=: read -r screen filename marker <<<"${entry}"
  capture_screen "${screen}" "${filename}" "${marker}" || exit 1
done

if ! "${ADB_S[@]}" pull "${DEVICE_CAPTURE_OUT}/app-observed-environment.json" "${OUT}/app-observed-environment.json" >/dev/null 2>&1; then
  FAILURE_REASON="missing app-observed-environment.json"
  exit 1
fi

python3 - <<'PY' "${MANIFEST}" "${OUT}" "${ROOT}" "${RUN_ID}" "${SOURCE_SHA}" "${SCREENS_JSON}" \
  "${AVD_NAME}" "${AVD_INFO}" "${API_LEVEL}" "${LANGUAGE}" "${FONT_SCALE}" "${REDUCE_MOTION}" \
  "${SERIAL}" "${WIDTH}" "${HEIGHT}" "${DENSITY}" "${REQUESTED_ENV}" "${APK_SHA}"
import json, subprocess, sys
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[3]) / "scripts" / "ops"))
from android_capture_lib import build_manifest, compare_observed_environment, write_manifest

(
    manifest_path, out_dir, root, run_id, source_sha, screens_json,
    avd_name, avd_info, api_level, language, font_scale, motion,
    serial, width, height, density, requested_env_path, apk_sha,
) = sys.argv[1:19]
source_tree = json.loads(subprocess.check_output(["python3", str(Path(root)/"scripts/ops/provenance_source_tree.py"), root, "--json"], text=True))
screens = json.loads(Path(screens_json).read_text(encoding="utf-8"))
requested = json.loads(Path(requested_env_path).read_text(encoding="utf-8"))
observed = json.loads(Path(out_dir, "app-observed-environment.json").read_text(encoding="utf-8"))
observed.setdefault("avdName", avd_name)
observed.setdefault("serial", serial)
observed.setdefault("reduceMotion", motion == "1")
env_errors = compare_observed_environment(requested, observed)
payload = build_manifest(
    out_dir=Path(out_dir),
    source_tree=source_tree,
    source_sha=source_sha,
    run_id=run_id,
    requested=requested,
    observed=observed,
    screens=screens,
    test_configuration={
        "avd_name": avd_name,
        "serial": serial,
        "device_model": avd_info,
        "api_level": api_level,
        "resolution": f"{width}x{height}",
        "density": density,
        "language": language,
        "font_scale": float(font_scale),
        "reduce_motion": motion == "1",
        "apk_sha256": apk_sha,
    },
    capture_completed=True,
    semantic_capture_ok=True,
    rc_source_sha=source_sha if source_tree.get("tracked_worktree_clean") else None,
    environment_ok=not env_errors,
    environment_errors=env_errors,
)
write_manifest(Path(manifest_path), payload)
print(manifest_path)
if env_errors:
    raise SystemExit("observed environment mismatch:\n" + "\n".join(env_errors))
PY

RUN_STATUS="PASS"
trap - EXIT
cleanup_emulator
echo "[android-shots] done → ${OUT} (${#SCREENS[@]} PNG, serial=${SERIAL})"
