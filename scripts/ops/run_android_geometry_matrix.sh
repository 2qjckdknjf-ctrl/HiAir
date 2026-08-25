#!/usr/bin/env bash
# Fail-closed Android responsive geometry matrix (development evidence only; dirty tree).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID="$ROOT/mobile/android"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/Users/alex/Library/Android/sdk}"
ADB="$ANDROID_SDK_ROOT/platform-tools/adb"
EMULATOR="$ANDROID_SDK_ROOT/emulator/emulator"
if [[ -n "${1:-}" ]]; then
  OUT="$(cd "$ROOT" && cd "$(dirname "$1")" && pwd)/$(basename "$1")"
else
  OUT="$ROOT/.evidence/android-geometry-matrix/$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$OUT"

SOURCE_SHA="$(git -C "$ROOT" rev-parse HEAD)"
DIRTY="$(git -C "$ROOT" status --porcelain | shasum -a 256 | awk '{print $1}')"
APK="$ANDROID/app/build/outputs/apk/debug/app-debug.apk"
APK_SHA="missing"

log() { echo "[geometry-matrix] $*" | tee -a "$OUT/run.log"; }

EMU_PID=""
EMU_SERIAL=""
STARTED_AVD=""

stop_emulator() {
  if [[ -n "$EMU_SERIAL" ]]; then
    "$ADB" -s "$EMU_SERIAL" shell wm size reset >/dev/null 2>&1 || true
    "$ADB" -s "$EMU_SERIAL" shell wm density reset >/dev/null 2>&1 || true
  fi
  if [[ -n "$EMU_PID" ]] && kill -0 "$EMU_PID" 2>/dev/null; then
    log "Stopping emulator pid=$EMU_PID serial=$EMU_SERIAL"
    "$ADB" -s "$EMU_SERIAL" emu kill >/dev/null 2>&1 || kill "$EMU_PID" 2>/dev/null || true
    wait "$EMU_PID" 2>/dev/null || true
  fi
  EMU_PID=""
  EMU_SERIAL=""
  STARTED_AVD=""
}

cleanup() { stop_emulator; }
trap cleanup EXIT

start_avd() {
  local avd_name="$1"
  local port="$2"
  stop_emulator
  EMU_SERIAL="emulator-${port}"
  log "Starting AVD=$avd_name port=$port serial=$EMU_SERIAL"
  "$EMULATOR" -avd "$avd_name" -port "$port" -no-snapshot-save -no-boot-anim >>"$OUT/emulator.log" 2>&1 &
  EMU_PID=$!
  STARTED_AVD="$avd_name"
  "$ADB" -s "$EMU_SERIAL" wait-for-device
  local boot=""
  for _ in $(seq 1 120); do
    boot="$("$ADB" -s "$EMU_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    [[ "$boot" == "1" ]] && break
    sleep 2
  done
  [[ "$boot" == "1" ]] || { log "FAIL boot timeout avd=$avd_name"; return 1; }
  local avd_actual="$("$ADB" -s "$EMU_SERIAL" emu avd name 2>/dev/null | tr -d '\r\n\"' | sed 's/OK$//')"
  [[ "$avd_actual" == "$avd_name" ]] || { log "FAIL avd name mismatch expected=$avd_name actual=$avd_actual"; return 1; }
}

dp_to_px() {
  python3 - <<PY
w,h,d=$1,$2,$3
scale=d/160.0
print(f"{round(w*scale)}x{round(h*scale)}")
PY
}

apply_profile() {
  local serial="$1"
  local width_dp="$2"
  local height_dp="$3"
  local density="$4"
  local px
  px="$(dp_to_px "$width_dp" "$height_dp" "$density")"
  "$ADB" -s "$serial" shell wm size "$px"
  "$ADB" -s "$serial" shell wm density "$density"
  sleep 2
}

observed_metrics() {
  local serial="$1"
  echo "wm_size=$("$ADB" -s "$serial" shell wm size | tr -d '\r')"
  echo "wm_density=$("$ADB" -s "$serial" shell wm density | tr -d '\r')"
}

OVERALL="PASS"
declare -a RESULTS=()

run_profile() {
  local avd="$1"
  local port="$2"
  local profile_id="$3"
  local width_dp="$4"
  local height_dp="$5"
  local density="$6"
  local expected_mode="$7"

  local logfile="$OUT/${profile_id}.log"
  local status="PASS"
  {
    echo "profile=$profile_id"
    echo "avd=$avd"
    echo "serial=emulator-${port}"
    echo "requested=${width_dp}x${height_dp}dp density=${density}dpi"
    echo "expected_mode=$expected_mode"
    echo "source_sha=$SOURCE_SHA"
    echo "dirty_tree_hash=$DIRTY"
    echo "rc_source_sha=null"
    echo "adb=$ADB"
  } >"$logfile"

  if [[ "$EMU_SERIAL" != "emulator-${port}" || "$STARTED_AVD" != "$avd" ]]; then
    start_avd "$avd" "$port" >>"$logfile" 2>&1 || status="FAIL"
  fi

  if [[ "$status" == "PASS" ]]; then
    if ! apply_profile "$EMU_SERIAL" "$width_dp" "$height_dp" "$density" >>"$logfile" 2>&1; then
      status="FAIL"
    else
      observed_metrics "$EMU_SERIAL" >>"$logfile"
      if ! (
        cd "$ANDROID"
        ANDROID_SERIAL="$EMU_SERIAL" ./gradlew connectedDebugAndroidTest \
          -Pandroid.testInstrumentationRunnerArguments.class=com.hiair.StoreScreenshotResponsiveGeometryTest \
          --quiet
      ) >>"$logfile" 2>&1; then
        status="FAIL"
      fi
    fi
  fi

  echo "result=$status" >>"$logfile"
  RESULTS+=("${profile_id}:${status}")
  if [[ "$status" != "PASS" ]]; then OVERALL="FAIL"; fi
  log "$profile_id => $status (expected=$expected_mode serial=$EMU_SERIAL)"
}

log "Building APK + JVM tests"
cd "$ANDROID"
./gradlew assembleDebug testDebugUnitTest --quiet
APK_SHA="$(shasum -a 256 "$APK" | awk '{print $1}')"

run_profile hiair-qa-phone 5554 compact-phone 360 800 420 STANDARD
run_profile hiair-qa-phone 5554 large-phone 411 891 420 STANDARD
run_profile hiair-qa-phone 5554 split-standard 540 800 320 STANDARD

run_profile hiair-qa-tablet 5556 medium-tablet 600 960 320 TABLET
run_profile hiair-qa-tablet 5556 tablet-portrait 800 1280 320 TABLET
run_profile hiair-qa-tablet 5556 boundary-840 840 1180 320 EXPANDED
run_profile hiair-qa-tablet 5556 expanded-tablet 1000 1600 320 EXPANDED
run_profile hiair-qa-tablet 5556 tablet-landscape 1280 800 320 EXPANDED

MANIFEST="$OUT/manifest.json"
{
  echo "{"
  echo "  \"overall\": \"$OVERALL\","
  echo "  \"source_sha\": \"$SOURCE_SHA\","
  echo "  \"dirty_tree_hash\": \"$DIRTY\","
  echo "  \"rc_source_sha\": null,"
  echo "  \"apk_sha256\": \"$APK_SHA\","
  echo "  \"adb\": \"$ADB\","
  echo "  \"profiles\": ["
  for i in "${!RESULTS[@]}"; do
    row="${RESULTS[$i]}"
    id="${row%%:*}"
    st="${row##*:}"
    [[ $i -gt 0 ]] && echo ","
    echo -n "    {\"id\": \"$id\", \"status\": \"$st\"}"
  done
  echo
  echo "  ]"
  echo "}"
} >"$MANIFEST"

log "Overall=$OVERALL manifest=$MANIFEST"
[[ "$OVERALL" == "PASS" ]] || exit 1
