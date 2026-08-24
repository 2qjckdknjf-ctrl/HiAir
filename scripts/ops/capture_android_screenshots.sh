#!/usr/bin/env bash
# Capture Android store screenshots with emulator isolation and semantic validation.
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
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
ADB="${SDK}/platform-tools/adb"
EMULATOR="${SDK}/emulator/emulator"
SOURCE_SHA="$(git -C "${ROOT}" rev-parse HEAD)"

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

mkdir -p "${OUT}"

if [[ "${HIAIR_ANDROID_ALLOW_REUSE:-0}" == "1" ]]; then
  SERIAL="$("${ADB}" devices | awk 'NR>1 && $2=="device"{print $1; exit}')"
  [[ -n "${SERIAL}" ]] || { echo "[android-shots] no booted device" >&2; exit 1; }
  echo "[android-shots] reusing serial=${SERIAL} (explicit allow)"
else
  if "${ADB}" devices | awk 'NR>1 && $2=="device"{exit 0} END{exit 1}'; then
    echo "[android-shots] refusing to reuse arbitrary booted emulator; set HIAIR_ANDROID_ALLOW_REUSE=1 to override" >&2
    exit 1
  fi
  if ! "${SDK}/cmdline-tools/latest/bin/avdmanager" list avd | grep -q "Name: ${AVD_NAME}"; then
    bash "${OPS}/setup_android_qa_avds.sh"
  fi
  EMU_LOG="${OUT}/emulator.log"
  nohup "${EMULATOR}" -avd "${AVD_NAME}" -no-snapshot-save -no-boot-anim -gpu swiftshader_indirect \
    >"${EMU_LOG}" 2>&1 &
  EMU_PID=$!
  for _ in $(seq 1 180); do
    SERIAL="$("${ADB}" devices | awk 'NR>1 && $2=="device"{print $1; exit}')"
    [[ -n "${SERIAL}" ]] && break
    sleep 2
  done
  [[ -n "${SERIAL}" ]] || { echo "[android-shots] emulator serial timeout" >&2; kill "${EMU_PID}" 2>/dev/null || true; exit 1; }
  echo "[android-shots] booted serial=${SERIAL} avd=${AVD_NAME}"
  boot_completed=""
  for _ in $(seq 1 120); do
    boot_completed="$("${ADB}" -s "${SERIAL}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
    [[ "${boot_completed}" == "1" ]] && break
    sleep 2
  done
  [[ "${boot_completed}" == "1" ]] || { echo "[android-shots] boot incomplete" >&2; exit 1; }
fi

ADB_S=("${ADB}" -s "${SERIAL}")

# Apply locale + font scale on device before install.
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
[[ -f "${APK}" ]] || { echo "[android-shots] missing APK" >&2; exit 1; }

"${ADB_S[@]}" install -r "${APK}" >/dev/null
"${ADB_S[@]}" shell pm clear com.hiair >/dev/null 2>&1 || true
"${ADB_S[@]}" shell mkdir -p "${DEVICE_CAPTURE_OUT}" >/dev/null

REQUESTED_ENV="${OUT}/requested-environment.json"
python3 - <<'PY' "${REQUESTED_ENV}" "${RUN_ID}" "${LANGUAGE}" "${FONT_SCALE}" "${REDUCE_MOTION}" "${AVD_NAME}" "${SERIAL}" "${SOURCE_SHA}"
import json, sys
path, run_id, lang, font_scale, motion, avd, serial, sha = sys.argv[1:]
payload = {
    "captureRunId": run_id,
    "language": lang,
    "fontScale": float(font_scale),
    "reduceMotion": motion == "1",
    "avdName": avd,
    "serial": serial,
    "sourceSha": sha,
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

MANIFEST_ENTRIES=()

capture_screen() {
  local screen="$1" filename="$2" marker="$3"
  local png="${OUT}/${filename}"
  local xml="${OUT}/${filename%.png}.xml"
  local log="${OUT}/${filename%.png}.logcat.txt"
  local stamp
  stamp="$("${ADB_S[@]}" shell date +%s 2>/dev/null | tr -d '\r')"
  "${ADB_S[@]}" logcat -c >/dev/null 2>&1 || true

  "${ADB_S[@]}" shell am force-stop com.hiair >/dev/null 2>&1 || true
  sleep 1
  local start_out
  start_out="$("${ADB_S[@]}" shell am start -W -n com.hiair/.AppMainActivity \
    -e HIAIR_STORE_SHOTS 1 \
    -e HIAIR_SCREEN "${screen}" \
    -e HIAIR_SHOT_LANGUAGE "${LANGUAGE}" \
    -e HIAIR_CAPTURE_RUN_ID "${RUN_ID}" \
    -e HIAIR_CAPTURE_OUT "${DEVICE_CAPTURE_OUT}" 2>&1)" || true
  if ! grep -q "Status: ok" <<<"${start_out}"; then
    echo "[android-shots] launch failed screen=${screen}: ${start_out}" >&2
    return 1
  fi

  for _ in $(seq 1 80); do
    if "${ADB_S[@]}" shell pidof com.hiair >/dev/null 2>&1; then break; fi
    sleep 0.5
  done
  "${ADB_S[@]}" shell pidof com.hiair >/dev/null 2>&1 || { echo "[android-shots] process missing ${screen}" >&2; return 1; }

  local fg=""
  for _ in $(seq 1 40); do
    fg="$("${ADB_S[@]}" shell dumpsys activity activities 2>/dev/null | awk '/mResumedActivity/{print; exit}' || true)"
    if grep -q "com.hiair" <<<"${fg}"; then break; fi
    sleep 0.25
  done
  grep -q "com.hiair" <<<"${fg}" || { echo "[android-shots] not foreground ${screen}: ${fg}" >&2; return 1; }

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

  local validation
  validation="$(python3 "${OPS}/android_capture_validate_cli.py" "${xml}" "${marker}" "com.hiair" 2>&1)" || {
    echo "[android-shots] semantic validation failed ${screen}: ${validation}" >&2
    return 1
  }

  local sha
  sha="$(python3 -c "import hashlib; print(hashlib.sha256(open('${png}','rb').read()).hexdigest())")"
  MANIFEST_ENTRIES+=("$(python3 - <<PY
import json
print(json.dumps({
  "filename": "${filename}",
  "expected_screen": "${screen}",
  "expected_marker": "${marker}",
  "foreground_package": "com.hiair",
  "semantic_validation_ok": True,
  "visual_review_result": "PENDING",
  "sha256": "${sha}",
  "hierarchy_xml": "${xml}",
  "logcat_path": "${log}",
}))
PY
)")
  echo "[android-shots] OK ${screen} → ${filename}"
}

for entry in "${SCREENS[@]}"; do
  IFS=: read -r screen filename marker <<<"${entry}"
  capture_screen "${screen}" "${filename}" "${marker}" || exit 1
done

"${ADB_S[@]}" pull "${DEVICE_CAPTURE_OUT}/app-observed-environment.json" "${OUT}/app-observed-environment.json" >/dev/null 2>&1 || {
  echo "[android-shots] missing app-observed-environment.json from device" >&2
  exit 1
}

SOURCE_TREE_JSON="$(python3 "${OPS}/provenance_source_tree.py" "${ROOT}" --json)"
python3 - <<'PY' "${MANIFEST}" "${OUT}" "${SOURCE_TREE_JSON}" "${RUN_ID}" "${AVD_NAME}" "${AVD_INFO}" "${API_LEVEL}" "${LANGUAGE}" "${FONT_SCALE}" "${SERIAL}" "${WIDTH}" "${HEIGHT}" "${DENSITY}" "${REQUESTED_ENV}" "${SOURCE_SHA}"
import hashlib, json, os, sys
from datetime import datetime, timezone

(
    manifest_path, out_dir, source_tree_json, run_id,
    avd_name, avd_info, api_level, language, font_scale, serial,
    width, height, density, requested_env_path, source_sha,
) = sys.argv[1:]

source_tree = json.loads(source_tree_json)
with open(requested_env_path, encoding="utf-8") as handle:
    requested = json.load(handle)
with open(os.path.join(out_dir, "app-observed-environment.json"), encoding="utf-8") as handle:
    observed = json.load(handle)

if observed.get("captureRunId") != run_id:
    raise SystemExit("observed captureRunId mismatch")

files = []
for name in sorted(f for f in os.listdir(out_dir) if f.endswith(".png")):
    path = os.path.join(out_dir, name)
    digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
    files.append({"filename": name, "sha256": digest, "size_bytes": os.path.getsize(path)})

payload = {
    "captured_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "artifact_kind": "android_store_screenshot_evidence",
    "provenance": source_tree,
    "source_sha": source_sha,
    "run_id": run_id,
    "test_configuration": {
        "avd_name": avd_name,
        "serial": serial,
        "device_model": avd_info,
        "api_level": api_level,
        "resolution": f"{width}x{height}",
        "density": density,
        "language": language,
        "font_scale": float(font_scale),
    },
    "requested_environment": requested,
    "app_observed_environment": observed,
    "output_dir": out_dir,
    "files": files,
    "semantic_validation": "PASS",
    "visual_review_result": "PENDING",
}
with open(manifest_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
print(manifest_path)
PY

if [[ "${HIAIR_ANDROID_KEEP_EMULATOR:-0}" != "1" && -n "${EMU_PID:-}" ]]; then
  kill "${EMU_PID}" 2>/dev/null || true
fi

echo "[android-shots] done → ${OUT} (${#SCREENS[@]} PNG, serial=${SERIAL})"
