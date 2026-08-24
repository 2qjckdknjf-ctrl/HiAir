#!/usr/bin/env bash
# Capture Android store screenshots (DEBUG) into evidence directory with provenance manifest.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID_DIR="${ROOT}/mobile/android"
OPS="${ROOT}/scripts/ops"
OUT="${HIAIR_ANDROID_SHOT_OUT:-${ROOT}/.evidence/android-screenshots/$(date +%Y%m%d-%H%M%S)}"
AVD_NAME="${HIAIR_ANDROID_AVD:-hiair-qa-phone}"
LANGUAGE="${HIAIR_SHOT_LANGUAGE:-en}"
FONT_SCALE="${HIAIR_ANDROID_FONT_SCALE:-1.0}"
RUN_STAMP="$(date +%s)"
MANIFEST="${OUT}/capture-manifest.json"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
ADB="${SDK}/platform-tools/adb"
EMULATOR="${SDK}/emulator/emulator"

SCREENS=(
  "dashboard:01-dashboard.png"
  "planner:02-planner.png"
  "insights:03-insights.png"
  "symptoms:04-symptoms.png"
  "settings:05-settings.png"
  "paywall:06-paywall.png"
  "onboarding:07-onboarding.png"
  "navigation:08-navigation-shell.png"
)

mkdir -p "${OUT}"

SOURCE_TREE_JSON="$(python3 "${OPS}/provenance_source_tree.py" "${ROOT}" --json)"

start_emulator() {
  if "${ADB}" devices | awk 'NR>1 && $2=="device"{exit 0} END{exit 1}'; then
    echo "[android-shots] reusing booted emulator"
    return 0
  fi
  if ! "${SDK}/cmdline-tools/latest/bin/avdmanager" list avd | grep -q "Name: ${AVD_NAME}"; then
    bash "${OPS}/setup_android_qa_avds.sh"
  fi
  nohup "${EMULATOR}" -avd "${AVD_NAME}" -no-snapshot-save -no-boot-anim -gpu swiftshader_indirect >/dev/null 2>&1 &
  "${ADB}" wait-for-device
  boot_completed=""
  for _ in $(seq 1 120); do
    boot_completed="$("${ADB}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
    [[ "${boot_completed}" == "1" ]] && break
    sleep 2
  done
  [[ "${boot_completed}" == "1" ]] || { echo "[android-shots] emulator boot timeout" >&2; exit 1; }
}

cd "${ANDROID_DIR}"
export JAVA_HOME="${JAVA_HOME:-/Users/alex/Library/Java/JavaVirtualMachines/jbr-17.0.14/Contents/Home}"
./gradlew assembleDebug --quiet

APK="${ANDROID_DIR}/app/build/outputs/apk/debug/app-debug.apk"
[[ -f "${APK}" ]] || { echo "[android-shots] missing APK" >&2; exit 1; }

start_emulator
"${ADB}" install -r "${APK}" >/dev/null

AVD_INFO="$("${ADB}" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || echo unknown)"
API_LEVEL="$("${ADB}" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r' || echo unknown)"

for entry in "${SCREENS[@]}"; do
  screen="${entry%%:*}"
  filename="${entry##*:}"
  echo "[android-shots] screen=${screen} → ${filename}"
  "${ADB}" shell am force-stop com.hiair >/dev/null 2>&1 || true
  "${ADB}" shell am start -n com.hiair/.AppMainActivity \
    -e HIAIR_STORE_SHOTS 1 \
    -e HIAIR_SCREEN "${screen}" \
    -e HIAIR_SHOT_LANGUAGE "${LANGUAGE}" >/dev/null
  sleep 3
  "${ADB}" exec-out screencap -p > "${OUT}/${filename}"
  if [[ "$(uname)" == "Darwin" ]]; then
    mtime=$(stat -f %m "${OUT}/${filename}")
  else
    mtime=$(stat -c %Y "${OUT}/${filename}")
  fi
  if (( mtime < RUN_STAMP - 30 )); then
    echo "[android-shots] stale PNG ${filename}" >&2
    exit 1
  fi
done

python3 - <<'PY' \
  "${MANIFEST}" "${OUT}" "${SOURCE_TREE_JSON}" "${RUN_STAMP}" \
  "${AVD_NAME}" "${AVD_INFO}" "${API_LEVEL}" "${LANGUAGE}" "${FONT_SCALE}"
import hashlib, json, os, sys
from datetime import datetime, timezone

(
    manifest_path, out_dir, source_tree_json, run_stamp,
    avd_name, avd_info, api_level, language, font_scale,
) = sys.argv[1:]

source_tree = json.loads(source_tree_json)
expected = [
    "01-dashboard.png", "02-planner.png", "03-insights.png", "04-symptoms.png",
    "05-settings.png", "06-paywall.png", "07-onboarding.png", "08-navigation-shell.png",
]
files = []
for name in expected:
    path = os.path.join(out_dir, name)
    if not os.path.isfile(path):
        raise SystemExit(f"missing {name}")
    digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
    files.append({"filename": name, "sha256": digest, "size_bytes": os.path.getsize(path)})

payload = {
    "captured_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "artifact_kind": "android_store_screenshot_evidence",
    "provenance": source_tree,
    "test_configuration": {
        "avd_name": avd_name,
        "device_model": avd_info,
        "api_level": api_level,
        "language": language,
        "font_scale": font_scale,
        "screens": expected,
    },
    "output_dir": out_dir,
    "run_stamp": int(run_stamp),
    "files": files,
}
with open(manifest_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
print(manifest_path)
PY

echo "[android-shots] done → ${OUT} (${#SCREENS[@]} PNG)"
