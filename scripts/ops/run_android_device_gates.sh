#!/usr/bin/env bash
# Mandatory pre-capture device gates for Android store-ready hardening.
# Fail-closed: any FAIL blocks capture.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID="$ROOT/mobile/android"
OPS="$ROOT/scripts/ops"
SDK="${ANDROID_SDK_ROOT:-/Users/alex/Library/Android/sdk}"
export ANDROID_SDK_ROOT="$SDK"
export PATH="$SDK/platform-tools:$SDK/emulator:$PATH"
ADB="$SDK/platform-tools/adb"
EMULATOR="$SDK/emulator/emulator"
JAVA_HOME="${JAVA_HOME:-/Users/alex/Library/Java/JavaVirtualMachines/jbr-17.0.14/Contents/Home}"
export JAVA_HOME

OUT="${1:-$ROOT/.evidence/android-device-gates/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT"

SOURCE_SHA="$(git -C "$ROOT" rev-parse HEAD)"
DIRTY="$(git -C "$ROOT" status --porcelain | shasum -a 256 | awk '{print $1}')"
APK="$ANDROID/app/build/outputs/apk/debug/app-debug.apk"

log() { echo "[device-gates] $*" | tee -a "$OUT/run.log"; }

declare -a GATES=()
record_gate() {
  local id="$1"
  local status="$2"
  GATES+=("${id}:${status}")
  log "GATE $id => $status"
}

OVERALL="PASS"
fail_gate() {
  local id="$1"
  record_gate "$id" "FAIL"
  OVERALL="FAIL"
}
pass_gate() {
  record_gate "$1" "PASS"
}

EMU_PID=""
EMU_SERIAL=""
STARTED_AVD=""

stop_emulator() {
  if [[ -n "$EMU_SERIAL" ]]; then
    "$ADB" -s "$EMU_SERIAL" shell wm size reset >/dev/null 2>&1 || true
    "$ADB" -s "$EMU_SERIAL" shell wm density reset >/dev/null 2>&1 || true
  fi
  if [[ -n "$EMU_PID" ]] && kill -0 "$EMU_PID" 2>/dev/null; then
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
  [[ "$boot" == "1" ]] || return 1
}

run_gradle() {
  local id="$1"
  shift
  local logfile="$OUT/${id}.log"
  if (cd "$ANDROID" && ./gradlew "$@" --quiet) >"$logfile" 2>&1; then
    pass_gate "$id"
  else
    fail_gate "$id"
  fi
}

run_connected() {
  local id="$1"
  local class="$2"
  local logfile="$OUT/${id}.log"
  if [[ -z "$EMU_SERIAL" ]]; then
    fail_gate "$id"
    return
  fi
  if (
    cd "$ANDROID"
    ANDROID_SERIAL="$EMU_SERIAL" ./gradlew connectedDebugAndroidTest \
      -Pandroid.testInstrumentationRunnerArguments.class="$class"
  ) >"$logfile" 2>&1; then
    pass_gate "$id"
  else
    fail_gate "$id"
  fi
}

log "source_sha=$SOURCE_SHA dirty_tree_hash=$DIRTY"

# JVM / compile gates (no device)
run_gradle assemble_debug assembleDebug
run_gradle unitTests testDebugUnitTest
run_gradle lint lintDebug
run_gradle compileAndroidTest compileDebugAndroidTestSources

# Shelf regression (host Python)
if python3 "$OPS/test_android_capture_shelf.py" >"$OUT/shelf-regression.log" 2>&1; then
  pass_gate shelf_regression
else
  fail_gate shelf_regression
fi

# Device gates
if ! start_avd hiair-qa-phone 5554; then
  fail_gate emulator_boot
else
  pass_gate emulator_boot
  record_gate "emulator_serial" "$EMU_SERIAL"
  record_gate "emulator_avd" "$STARTED_AVD"

  fg="$("$ADB" -s "$EMU_SERIAL" shell dumpsys window windows 2>/dev/null | grep -m1 mCurrentFocus || true)"
  echo "foreground=$fg" >>"$OUT/emulator.log"

  run_connected geometry_responsive com.hiair.StoreScreenshotResponsiveGeometryTest
  run_connected geometry_root_shell com.hiair.RootShellLayoutGeometryTest
  run_connected cold_start_paywall com.hiair.StoreScreenshotColdStartPaywallTest
  run_connected cold_start_onboarding com.hiair.StoreScreenshotColdStartOnboardingTest
  run_connected cold_start_symptoms com.hiair.StoreScreenshotColdStartSymptomsTest
fi

MANIFEST="$OUT/manifest.json"
{
  echo "{"
  echo "  \"overall\": \"$OVERALL\","
  echo "  \"source_sha\": \"$SOURCE_SHA\","
  echo "  \"dirty_tree_hash\": \"$DIRTY\","
  echo "  \"emulator_serial\": \"${EMU_SERIAL:-}\","
  echo "  \"emulator_avd\": \"${STARTED_AVD:-}\","
  echo "  \"gates\": ["
  for i in "${!GATES[@]}"; do
    row="${GATES[$i]}"
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
