#!/usr/bin/env bash
# Targeted responsive visual smoke (development evidence; dirty tree OK).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID_DIR="${ROOT}/mobile/android"
OPS="${ROOT}/scripts/ops"
OUT="${1:-$ROOT/.evidence/android-targeted-visual/$(date +%Y%m%d-%H%M%S)}"
if [[ "${OUT}" != /* ]]; then
  OUT="${ROOT}/${OUT}"
fi
mkdir -p "$OUT"

SDK="${ANDROID_SDK_ROOT:-/Users/alex/Library/Android/sdk}"
export ANDROID_SDK_ROOT="$SDK"
export PATH="$SDK/platform-tools:$SDK/emulator:$PATH"
ADB="${SDK}/platform-tools/adb"
EMULATOR="${SDK}/emulator/emulator"
LANGUAGE="${HIAIR_SHOT_LANGUAGE:-en}"
RUN_ID="${HIAIR_CAPTURE_RUN_ID:-targeted-$(date +%s)}"
SOURCE_SHA="$(git -C "$ROOT" rev-parse HEAD)"
DIRTY="$(git -C "$ROOT" status --porcelain | shasum -a 256 | awk '{print $1}')"

log() { echo "[targeted-visual] $*" | tee -a "$OUT/run.log"; }

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
  local width_dp="$1"
  local height_dp="$2"
  local density="$3"
  local px
  px="$(dp_to_px "$width_dp" "$height_dp" "$density")"
  "$ADB" -s "$EMU_SERIAL" shell wm size "$px"
  "$ADB" -s "$EMU_SERIAL" shell wm density "$density"
  sleep 2
}

capture_one() {
  local shot_id="$1"
  local avd="$2"
  local port="$3"
  local width_dp="$4"
  local height_dp="$5"
  local density="$6"
  local screen="$7"
  local marker="$8"
  local filename="$9"

  local logfile="$OUT/${shot_id}.log"
  local raw_png="$OUT/${shot_id}.raw.png"
  local app_png="$OUT/${shot_id}.app.png"
  local xml="$OUT/${shot_id}.xml"
  local status="PASS"

  {
    echo "shot_id=$shot_id"
    echo "avd=$avd"
    echo "serial=emulator-${port}"
    echo "requested=${width_dp}x${height_dp}dp density=${density}dpi"
    echo "screen=$screen marker=$marker"
    echo "source_sha=$SOURCE_SHA"
    echo "dirty_tree_hash=$DIRTY"
    echo "rc_source_sha=null"
  } >"$logfile"

  if [[ "$EMU_SERIAL" != "emulator-${port}" || "$STARTED_AVD" != "$avd" ]]; then
    start_avd "$avd" "$port" >>"$logfile" 2>&1 || status="FAIL"
  fi

  if [[ "$status" == "PASS" ]]; then
    apply_profile "$width_dp" "$height_dp" "$density" >>"$logfile" 2>&1 || status="FAIL"
  fi

  if [[ "$status" == "PASS" ]]; then
    "$ADB" -s "$EMU_SERIAL" shell pm clear com.hiair >>"$logfile" 2>&1 || status="FAIL"
  fi

  if [[ "$status" == "PASS" ]]; then
    "$ADB" -s "$EMU_SERIAL" shell "settings put system system_locales ${LANGUAGE}" >/dev/null 2>&1 || true
    "$ADB" -s "$EMU_SERIAL" shell am force-stop com.hiair >/dev/null 2>&1 || true
    "$ADB" -s "$EMU_SERIAL" logcat -c >/dev/null 2>&1 || true
    sleep 1
    local start_out
    start_out="$("$ADB" -s "$EMU_SERIAL" shell am start -W -n com.hiair/.AppMainActivity -f 0x10008000 \
      --es HIAIR_STORE_SHOTS 1 \
      --es HIAIR_SCREEN "$screen" \
      --es HIAIR_SHOT_LANGUAGE "$LANGUAGE" \
      --es HIAIR_CAPTURE_RUN_ID "$RUN_ID" 2>&1)" || true
    echo "$start_out" >>"$logfile"
    if ! grep -q "Status: ok" <<<"$start_out"; then
      status="FAIL"
    fi
  fi

  local reject_reason=""
  local found=0
  if [[ "$status" == "PASS" ]]; then
    for _ in $(seq 1 240); do
      if "$ADB" -s "$EMU_SERIAL" shell uiautomator dump /sdcard/window_dump.xml >/dev/null 2>&1; then
        if "$ADB" -s "$EMU_SERIAL" shell grep -q "$marker" /sdcard/window_dump.xml 2>/dev/null; then
          found=1
          break
        fi
      fi
      sleep 0.05
    done
    if [[ "$found" != "1" ]]; then
      echo "timeout waiting for marker=$marker" >>"$logfile"
      reject_reason="marker_timeout:$marker"
      status="FAIL"
    fi
  fi

  # Always capture evidence before returning FAIL/PASS.
  "$ADB" -s "$EMU_SERIAL" shell uiautomator dump /sdcard/window_dump.xml >/dev/null 2>&1 || true
  "$ADB" -s "$EMU_SERIAL" pull /sdcard/window_dump.xml "$xml" >/dev/null 2>&1 || true
  "$ADB" -s "$EMU_SERIAL" exec-out screencap -p >"$raw_png" 2>/dev/null || true
  local logcat_file="$OUT/${shot_id}.logcat.txt"
  local window_dump="$OUT/${shot_id}.window.txt"
  "$ADB" -s "$EMU_SERIAL" logcat -d -t 2000 '*:S' 'HiAirStoreReady:D' 'AndroidRuntime:E' 'ActivityManager:I' >"$logcat_file" 2>/dev/null || \
    "$ADB" -s "$EMU_SERIAL" logcat -d -t 2000 >"$logcat_file" 2>/dev/null || true
  "$ADB" -s "$EMU_SERIAL" shell dumpsys window windows >"$window_dump" 2>/dev/null || true
  if [[ -z "$reject_reason" && -f "$logcat_file" ]]; then
    reject_reason="$(rg -m1 -o 'HiAirStoreReady: reject target=[^ ]+ reason=\S+' "$logcat_file" | sed 's/.*reason=//' || true)"
  fi
  local fg pid
  fg="$("$ADB" -s "$EMU_SERIAL" shell dumpsys activity activities 2>/dev/null | rg -m1 "mResumedActivity|topResumedActivity" | tr -d '\r' || true)"
  pid="$("$ADB" -s "$EMU_SERIAL" shell pidof com.hiair 2>/dev/null | tr -d '\r' || true)"

  # Always persist evidence before returning FAIL/PASS to the caller.
  if ! python3 "$OPS/android_capture_persist_evidence.py" \
    --out-dir "$OUT" \
    --shot-id "$shot_id" \
    --status "$status" \
    --png "$raw_png" \
    --xml "$xml" \
    --logcat "$logcat_file" \
    --window-dump "$window_dump" \
    --reject-reason "$reject_reason" \
    --foreground "$fg" \
    --pid "$pid" \
    --apk-sha256 "$APK_SHA" \
    --source-sha "$SOURCE_SHA" \
    --dirty-hash "$DIRTY" >>"$logfile" 2>&1; then
    if [[ "$status" == "PASS" ]]; then
      reject_reason="${reject_reason:-shelf_or_crop_failure}"
      status="FAIL"
    fi
  fi

  if [[ "$status" == "PASS" ]]; then
    if ! python3 "$OPS/android_capture_validate_cli.py" "$xml" "$marker" com.hiair >>"$logfile" 2>&1; then
      reject_reason="semantic_validator_failed"
      status="FAIL"
      python3 "$OPS/android_capture_persist_evidence.py" \
        --out-dir "$OUT" \
        --shot-id "$shot_id" \
        --status "$status" \
        --png "$raw_png" \
        --xml "$xml" \
        --logcat "$logcat_file" \
        --window-dump "$window_dump" \
        --reject-reason "$reject_reason" \
        --foreground "$fg" \
        --pid "$pid" \
        --apk-sha256 "$APK_SHA" \
        --source-sha "$SOURCE_SHA" \
        --dirty-hash "$DIRTY" >>"$logfile" 2>&1 || true
    fi
  fi

  echo "wm_size=$("$ADB" -s "$EMU_SERIAL" shell wm size 2>/dev/null | tr -d '\r')" >>"$logfile"
  echo "foreground=$fg" >>"$logfile"
  echo "pid=$pid" >>"$logfile"
  echo "reject_reason=$reject_reason" >>"$logfile"
  echo "result=$status" >>"$logfile"
  log "$shot_id => $status (${shot_id}.app.png)"
  RESULTS+=("${shot_id}:${status}")
  [[ "$status" == "PASS" ]] || OVERALL="FAIL"

  # End-of-scroll evidence for scroll-heavy store screens.
  case "$shot_id" in
    tablet-landscape-paywall|phone-planner|tablet-landscape-planner|phone-symptoms|tablet-landscape-symptoms|medium-dashboard)
      if [[ "$status" == "PASS" ]]; then
        scroll_capture_end "$shot_id" "$xml" "$logcat_file" "$window_dump" "$fg" "$pid" || true
      fi
      ;;
  esac
}

scroll_capture_end() {
  local base_shot="$1"
  local xml="$2"
  local logcat_file="$3"
  local window_dump="$4"
  local fg="$5"
  local pid="$6"
  local end_id="${base_shot}-end-scroll"
  local raw_png="$OUT/${end_id}.raw.png"
  local end_xml="$OUT/${end_id}.xml"
  for _ in 1 2 3 4 5 6; do
    "$ADB" -s "$EMU_SERIAL" shell input swipe 540 1600 540 400 350 >/dev/null 2>&1 || true
    sleep 0.25
  done
  sleep 0.5
  "$ADB" -s "$EMU_SERIAL" shell uiautomator dump /sdcard/window_dump.xml >/dev/null 2>&1 || true
  "$ADB" -s "$EMU_SERIAL" pull /sdcard/window_dump.xml "$end_xml" >/dev/null 2>&1 || true
  "$ADB" -s "$EMU_SERIAL" exec-out screencap -p >"$raw_png" 2>/dev/null || true
  local end_status="PASS"
  if ! python3 "$OPS/android_capture_persist_evidence.py" \
    --out-dir "$OUT" \
    --shot-id "$end_id" \
    --status "PASS" \
    --png "$raw_png" \
    --xml "$end_xml" \
    --logcat "$logcat_file" \
    --window-dump "$window_dump" \
    --reject-reason "" \
    --foreground "$fg" \
    --pid "$pid" \
    --apk-sha256 "$APK_SHA" \
    --source-sha "$SOURCE_SHA" \
    --dirty-hash "$DIRTY" >>"$OUT/${end_id}.log" 2>&1; then
    end_status="FAIL"
    OVERALL="FAIL"
  fi
  log "$end_id => $end_status (${end_id}.app.png)"
  RESULTS+=("${end_id}:${end_status}")
}

OVERALL="PASS"
declare -a RESULTS=()

log "Building debug APK"
cd "$ANDROID_DIR"
./gradlew assembleDebug --quiet
APK="${ANDROID_DIR}/app/build/outputs/apk/debug/app-debug.apk"
APK_SHA="$(shasum -a 256 "$APK" | awk '{print $1}')"

# Recheck-first order (semantic blockers before visual reshoots).
# Optional filter: HIAIR_SHOT_FILTER=medium-settings,tablet-portrait-paywall
# shot_id:avd:port:width_dp:height_dp:density:screen:marker:filename
SHOTS=(
  "medium-settings:hiair-qa-tablet:5556:600:960:320:settings:store.settings.ready:medium-settings.png"
  "tablet-portrait-paywall:hiair-qa-tablet:5556:800:1280:320:paywall:store.paywall.ready:tablet-portrait-paywall.png"
  "tablet-landscape-paywall:hiair-qa-tablet:5556:1280:800:320:paywall:store.paywall.ready:tablet-landscape-paywall.png"
  "tablet-portrait-onboarding:hiair-qa-tablet:5556:800:1280:320:onboarding:store.onboarding.ready:tablet-portrait-onboarding.png"
  "tablet-landscape-onboarding:hiair-qa-tablet:5556:1280:800:320:onboarding:store.onboarding.ready:tablet-landscape-onboarding.png"
  "expanded-navigation:hiair-qa-tablet:5556:1000:1600:320:navigation:store.navigation.ready:expanded-navigation.png"
  "medium-dashboard:hiair-qa-tablet:5556:600:960:320:dashboard:store.dashboard.ready:medium-dashboard.png"
  "tablet-landscape-dashboard:hiair-qa-tablet:5556:1280:800:320:dashboard:store.dashboard.ready:tablet-landscape-dashboard.png"
  "phone-planner:hiair-qa-phone:5554:411:891:420:planner:store.planner.ready:phone-planner.png"
  "tablet-landscape-planner:hiair-qa-tablet:5556:1280:800:320:planner:store.planner.ready:tablet-landscape-planner.png"
  "phone-symptoms:hiair-qa-phone:5554:411:891:420:symptoms:store.symptoms.ready:phone-symptoms.png"
  "tablet-landscape-symptoms:hiair-qa-tablet:5556:1280:800:320:symptoms:store.symptoms.ready:tablet-landscape-symptoms.png"
)

FILTER="${HIAIR_SHOT_FILTER:-}"
for entry in "${SHOTS[@]}"; do
  IFS=: read -r shot_id avd port w h d screen marker filename <<<"$entry"
  if [[ -n "$FILTER" ]]; then
    case ",$FILTER," in
      *",$shot_id,"*) ;;
      *) continue ;;
    esac
  fi
  if [[ "$EMU_SERIAL" != "emulator-${port}" || "$STARTED_AVD" != "$avd" ]]; then
    stop_emulator
    start_avd "$avd" "$port"
    "$ADB" -s "$EMU_SERIAL" install -r "$APK" >>"$OUT/install.log" 2>&1
  fi
  capture_one "$shot_id" "$avd" "$port" "$w" "$h" "$d" "$screen" "$marker" "$filename"
done

MANIFEST="$OUT/manifest.json"
{
  echo "{"
  echo "  \"overall\": \"$OVERALL\","
  echo "  \"source_sha\": \"$SOURCE_SHA\","
  echo "  \"dirty_tree_hash\": \"$DIRTY\","
  echo "  \"rc_source_sha\": null,"
  echo "  \"apk_sha256\": \"$APK_SHA\","
  echo "  \"adb\": \"$ADB\","
  echo "  \"shots\": ["
  for i in "${!RESULTS[@]}"; do
    row="${RESULTS[$i]}"
    id="${row%%:*}"
    st="${row##*:}"
    [[ $i -gt 0 ]] && echo ","
    echo -n "    {\"id\": \"$id\", \"status\": \"$st\", \"screenshot\": \"${id}.app.png\", \"raw_screenshot\": \"${id}.raw.png\", \"visual_review\": \"PENDING\"}"
  done
  echo
  echo "  ]"
  echo "}"
} >"$MANIFEST"

log "Overall=$OVERALL manifest=$MANIFEST"

python3 "$OPS/generate_android_visual_review.py" \
  --out-dir "$OUT" \
  --manifest "manifest.json" \
  --prior-review ".evidence/android-targeted-visual/dev-20260825-v4-visual-4b/visual-review.json" >>"$OUT/run.log" 2>&1 || true

if [[ -f "$OUT/visual-review.json" ]]; then
  python3 "$OPS/sync_android_visual_manifest.py" --out-dir "$OUT" >>"$OUT/run.log" 2>&1 || true
fi

[[ "$OVERALL" == "PASS" ]] || exit 1
