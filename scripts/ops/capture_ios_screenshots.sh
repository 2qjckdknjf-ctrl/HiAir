#!/usr/bin/env bash
# Capture iOS ASC screenshots via StoreScreenshotTests into an evidence directory.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS_DIR="${ROOT}/mobile/ios"
OPS="${ROOT}/scripts/ops"
OUT="${HIAIR_SCREENSHOT_OUT:-${ROOT}/.evidence/ios-screenshots/$(date +%Y%m%d-%H%M%S)}"
SIM_NAME="${IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
LANGUAGE="${HIAIR_SHOT_LANGUAGE:-en}"
ALLOW_TRACKED_OVERWRITE="${HIAIR_SCREENSHOT_ALLOW_TRACKED:-0}"
ALLOW_NONEMPTY_OUT="${HIAIR_SCREENSHOT_ALLOW_NONEMPTY:-0}"
ACCESSIBILITY_SIZE="${HIAIR_SHOT_ACCESSIBILITY:-standard}"
REDUCE_MOTION="${HIAIR_SHOT_REDUCE_MOTION:-system}"
REDUCE_TRANSPARENCY="${HIAIR_SHOT_REDUCE_TRANSPARENCY:-system}"
RUN_STAMP="$(date +%s)"
RESULT_ROOT="${OUT}/.run-${RUN_STAMP}"
RESULT_BUNDLE="${RESULT_ROOT}/StoreScreenshotTests.xcresult"
PERSISTENT_RESULT="${OUT}/StoreScreenshotTests.xcresult"
MANIFEST="${OUT}/capture-manifest.json"

EXPECTED_SHOTS=(
  "01-auth.png" "01b-onboarding.png" "02-dashboard.png" "03-planner.png"
  "04-insights.png" "05-symptoms.png" "06-settings.png" "06b-settings-subscription.png"
  "07-paywall.png" "07b-paywall-restore.png"
)

if [[ "${OUT}" == *"docs/brand/store-assets"* && "${ALLOW_TRACKED_OVERWRITE}" != "1" ]]; then
  echo "[screenshots] Refusing tracked store assets without HIAIR_SCREENSHOT_ALLOW_TRACKED=1" >&2
  exit 1
fi

mkdir -p "${OUT}"

if [[ "${ALLOW_NONEMPTY_OUT}" != "1" ]]; then
  shopt -s nullglob
  existing=("${OUT}"/*.png)
  shopt -u nullglob
  if ((${#existing[@]} > 0)); then
    echo "[screenshots] Output directory already contains PNG captures: ${OUT}" >&2
    exit 1
  fi
fi

SOURCE_TREE_JSON="$(python3 "${OPS}/provenance_source_tree.py" "${ROOT}" --json)"
BASE_COMMIT_SHA="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['head_sha'])" "${SOURCE_TREE_JSON}")"
TRACKED_CLEAN="$(python3 -c "import json,sys; print('true' if json.loads(sys.argv[1])['tracked_worktree_clean'] else 'false')" "${SOURCE_TREE_JSON}")"
SOURCE_REPRO="$(python3 -c "import json,sys; print('true' if json.loads(sys.argv[1])['source_tree_reproducible'] else 'false')" "${SOURCE_TREE_JSON}")"
RC_SOURCE_SHA="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['rc_source_sha'] or '')" "${SOURCE_TREE_JSON}")"

SIM_JSON="$(bash "${OPS}/resolve_ios_simulator.sh" "${SIM_NAME}")"
DEST="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['destination'])" "${SIM_JSON}")"
SIM_UDID="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['udid'])" "${SIM_JSON}")"
SIM_RUNTIME_ID="$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('runtime_identifier') or '')" "${SIM_JSON}")"
SIM_RUNTIME_VER="$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('runtime_version') or '')" "${SIM_JSON}")"
SIM_DEVICE_NAME="$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('name') or '')" "${SIM_JSON}")"

echo "[screenshots] destination=${DEST}"
echo "[screenshots] device=${SIM_DEVICE_NAME} udid=${SIM_UDID} runtime=${SIM_RUNTIME_ID}"
echo "[screenshots] output=${OUT}"
echo "[screenshots] requested accessibility=${ACCESSIBILITY_SIZE} reduce_motion=${REDUCE_MOTION} reduce_transparency=${REDUCE_TRANSPARENCY}"

rm -rf "${RESULT_ROOT}"
mkdir -p "${RESULT_ROOT}"

cd "${IOS_DIR}"

set +e
xcodebuild \
  -project HiAir.xcodeproj \
  -scheme HiAir \
  -destination "${DEST}" \
  -resultBundlePath "${RESULT_BUNDLE}" \
  test \
  -only-testing:HiAirUITests/StoreScreenshotTests \
  "TEST_RUNNER_HIAIR_SCREENSHOT_OUT=${OUT}" \
  "TEST_RUNNER_HIAIR_SHOT_LANGUAGE=${LANGUAGE}" \
  "TEST_RUNNER_HIAIR_SCREENSHOT_RUN_STAMP=${RUN_STAMP}" \
  "TEST_RUNNER_HIAIR_CAPTURE_RUN_ID=${RUN_STAMP}" \
  "TEST_RUNNER_HIAIR_SHOT_ACCESSIBILITY=${ACCESSIBILITY_SIZE}" \
  "TEST_RUNNER_HIAIR_SHOT_REDUCE_MOTION=${REDUCE_MOTION}" \
  "TEST_RUNNER_HIAIR_SHOT_REDUCE_TRANSPARENCY=${REDUCE_TRANSPARENCY}" \
  "TEST_RUNNER_HIAIR_REPORT_SHOT_ENV=1"
BUILD_STATUS=$?
set -e

if [[ -d "${RESULT_BUNDLE}" ]]; then
  rm -rf "${PERSISTENT_RESULT}"
  cp -R "${RESULT_BUNDLE}" "${PERSISTENT_RESULT}"
fi

ATTACH_DIR="${OUT}/xcresult-attachments"
if command -v xcrun >/dev/null 2>&1 && [[ -d "${RESULT_BUNDLE}" ]]; then
  mkdir -p "${ATTACH_DIR}"
  xcrun xcresulttool export attachments --path "${RESULT_BUNDLE}" --output-path "${ATTACH_DIR}" 2>/dev/null || true
  python3 - <<'PY' "${ATTACH_DIR}" "${OUT}"
import json, os, re, shutil, sys
attach_dir, out_dir = sys.argv[1], sys.argv[2]
manifest_path = os.path.join(attach_dir, "manifest.json")
if not os.path.isfile(manifest_path):
    raise SystemExit(0)
with open(manifest_path, encoding="utf-8") as handle:
    data = json.load(handle)
for group in data:
    for item in group.get("attachments", []):
        exported = item.get("exportedFileName")
        suggested = item.get("suggestedHumanReadableName", "")
        if not exported:
            continue
        if "observed-environment" in suggested.lower():
            continue
        if not (exported.endswith(".png") or suggested.endswith(".png") or ".png" in suggested.lower()):
            continue
        src = os.path.join(attach_dir, exported)
        if not os.path.isfile(src):
            src = os.path.join(out_dir, exported)
        if not os.path.isfile(src):
            continue
        base = suggested.split("_0_")[0] if suggested else exported
        base = re.sub(r"[^a-zA-Z0-9._-]", "-", base)
        if not base.endswith(".png"):
            base += ".png"
        shutil.copy2(src, os.path.join(out_dir, base))
PY
fi

python3 - <<'PY' "${OUT}" "${RUN_STAMP}" "${BUILD_STATUS}"
import hashlib, os, sys
out_dir, run_stamp, build_status = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
expected = [
    "01-auth.png","01b-onboarding.png","02-dashboard.png","03-planner.png","04-insights.png",
    "05-symptoms.png","06-settings.png","06b-settings-subscription.png","07-paywall.png","07b-paywall-restore.png",
]
pngs = sorted(f for f in os.listdir(out_dir) if f.endswith(".png") and f in expected)
if set(pngs) != set(expected):
    all_pngs = sorted(f for f in os.listdir(out_dir) if f.endswith(".png"))
    raise SystemExit(f"[screenshots] PNG set mismatch missing={set(expected)-set(all_pngs)} extra={set(all_pngs)-set(expected)}")
for name in expected:
    if int(os.path.getmtime(os.path.join(out_dir, name))) < run_stamp - 30:
        raise SystemExit(f"[screenshots] Stale PNG: {name}")
if build_status != 0:
    raise SystemExit(build_status)
PY

APP_OBSERVED="${OUT}/app-observed-environment.json"
REQUESTED="${OUT}/requested-environment.json"

if [[ ! -f "${APP_OBSERVED}" ]]; then
  echo "[screenshots] Missing app-observed-environment.json (app must write runtime proof)" >&2
  exit 1
fi
if [[ ! -f "${REQUESTED}" ]]; then
  echo "[screenshots] Missing requested-environment.json from UI test" >&2
  exit 1
fi

python3 - <<'PY' "${APP_OBSERVED}" "${REQUESTED}" "${ACCESSIBILITY_SIZE}" "${REDUCE_MOTION}" "${REDUCE_TRANSPARENCY}" "${LANGUAGE}" "${RUN_STAMP}"
import json, sys
app_path, req_path, req_a11y, req_motion, req_transparency, req_lang, run_stamp = sys.argv[1:]
with open(app_path, encoding="utf-8") as handle:
    observed = json.load(handle)
with open(req_path, encoding="utf-8") as handle:
    requested = json.load(handle)

errors = []
if observed.get("captureRunId") != run_stamp:
    errors.append(f"captureRunId mismatch app={observed.get('captureRunId')} expected={run_stamp}")
if requested.get("captureRunId") != run_stamp:
    errors.append(f"requested captureRunId mismatch")

if req_lang and not str(observed.get("locale", "")).lower().startswith(req_lang.lower()[:2]):
    errors.append(f"locale expected prefix {req_lang}, got {observed.get('locale')}")

if req_a11y in ("accessibility3", "a11y3"):
    if "AccessibilityM" not in str(observed.get("contentSizeCategory", "")):
        errors.append(f"contentSizeCategory expected AccessibilityM, got {observed.get('contentSizeCategory')}")
elif req_a11y in ("accessibility5", "a11y5"):
    if "AccessibilityXXXL" not in str(observed.get("contentSizeCategory", "")):
        errors.append(f"contentSizeCategory expected AccessibilityXXXL, got {observed.get('contentSizeCategory')}")

if req_motion not in ("system", ""):
    want = req_motion in ("1", "true", "yes")
    if observed.get("reduceMotionEnabled") != want:
        errors.append(f"reduceMotion requested={req_motion} observed={observed.get('reduceMotionEnabled')}")

if req_transparency not in ("system", ""):
    want = req_transparency in ("1", "true", "yes")
    if observed.get("reduceTransparencyEnabled") != want:
        errors.append(f"reduceTransparency requested={req_transparency} observed={observed.get('reduceTransparencyEnabled')}")

if errors:
    raise SystemExit("[screenshots] App observed environment mismatch:\n" + "\n".join(errors))
print("[screenshots] app-observed-environment validated against requested")
PY

python3 - <<'PY' \
  "${MANIFEST}" "${OUT}" "${DEST}" "${LANGUAGE}" \
  "${ACCESSIBILITY_SIZE}" "${REDUCE_MOTION}" "${REDUCE_TRANSPARENCY}" \
  "${SOURCE_TREE_JSON}" "${RUN_STAMP}" "${BUILD_STATUS}" \
  "${PERSISTENT_RESULT}" "${SIM_UDID}" "${SIM_DEVICE_NAME}" "${SIM_RUNTIME_ID}" "${SIM_RUNTIME_VER}" \
  "${APP_OBSERVED}" "${REQUESTED}"
import hashlib, json, os, sys
from datetime import datetime, timezone

(
    manifest_path, out_dir, destination, language,
    req_a11y, req_motion, req_transparency,
    source_tree_json, run_stamp, build_status,
    result_bundle, sim_udid, sim_name, runtime_id, runtime_ver, app_observed_path, requested_path,
) = sys.argv[1:]

source_tree = json.loads(source_tree_json)
with open(app_observed_path, encoding="utf-8") as handle:
    app_observed = json.load(handle)
with open(requested_path, encoding="utf-8") as handle:
    requested_environment = json.load(handle)

expected = [
    "01-auth.png","01b-onboarding.png","02-dashboard.png","03-planner.png","04-insights.png",
    "05-symptoms.png","06-settings.png","06b-settings-subscription.png","07-paywall.png","07b-paywall-restore.png",
]
files = []
for name in expected:
    path = os.path.join(out_dir, name)
    digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
    files.append({"filename": name, "sha256": digest, "size_bytes": os.path.getsize(path)})

xcresult_sha256 = None
if os.path.isdir(result_bundle):
    hasher = hashlib.sha256()
    for dirpath, _, filenames in sorted(os.walk(result_bundle)):
        for filename in sorted(filenames):
            filepath = os.path.join(dirpath, filename)
            hasher.update(os.path.relpath(filepath, result_bundle).encode())
            hasher.update(b"\0")
            with open(filepath, "rb") as handle:
                while chunk := handle.read(1024 * 1024):
                    hasher.update(chunk)
    xcresult_sha256 = hasher.hexdigest()

payload = {
    "captured_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "artifact_kind": "ios_store_screenshot_evidence",
    "provenance": {
        **source_tree,
        "note": source_tree.get("note"),
    },
    "test_configuration": {
        "suite": "HiAirUITests/StoreScreenshotTests",
        "destination": destination,
        "simulator_udid": sim_udid,
        "simulator_name": sim_name,
        "runtime_identifier": runtime_id,
        "runtime_version": runtime_ver,
        "language": language,
        "requested_accessibility_text_size": req_a11y,
        "requested_reduce_motion": req_motion,
        "requested_reduce_transparency": req_transparency,
        "xcodebuild_exit_status": int(build_status),
    },
    "requested_environment": requested_environment,
    "app_observed_environment": app_observed,
    "output_dir": out_dir,
    "result_bundle": result_bundle,
    "result_bundle_sha256": xcresult_sha256,
    "run_stamp": int(run_stamp),
    "files": files,
}

with open(manifest_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY

rm -rf "${RESULT_ROOT}"
echo "[screenshots] done → ${OUT} (${#EXPECTED_SHOTS[@]} PNG)"
