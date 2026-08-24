#!/usr/bin/env bash
# Capture iOS ASC screenshots via StoreScreenshotTests into an evidence directory.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS_DIR="${ROOT}/mobile/ios"
OUT="${HIAIR_SCREENSHOT_OUT:-${ROOT}/.evidence/ios-screenshots/$(date +%Y%m%d-%H%M%S)}"
DEST="${IOS_SCREENSHOT_DEST:-platform=iOS Simulator,name=iPhone 17 Pro}"
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

EXPECTED_SHOTS=(
  "01-auth.png"
  "01b-onboarding.png"
  "02-dashboard.png"
  "03-planner.png"
  "04-insights.png"
  "05-symptoms.png"
  "06-settings.png"
  "06b-settings-subscription.png"
  "07-paywall.png"
  "07b-paywall-restore.png"
)

if [[ "${OUT}" == *"docs/brand/store-assets"* && "${ALLOW_TRACKED_OVERWRITE}" != "1" ]]; then
  echo "[screenshots] Refusing tracked store assets without HIAIR_SCREENSHOT_ALLOW_TRACKED=1" >&2
  exit 1
fi

mkdir -p "${OUT}"

# Require empty output directory (no pre-existing captures).
if [[ "${ALLOW_NONEMPTY_OUT}" != "1" ]]; then
  shopt -s nullglob
  existing=("${OUT}"/*.png)
  shopt -u nullglob
  if ((${#existing[@]} > 0)); then
    echo "[screenshots] Output directory already contains PNG captures: ${OUT}" >&2
    echo "[screenshots] Use a fresh directory or set HIAIR_SCREENSHOT_ALLOW_NONEMPTY=1 to override." >&2
    ls -la "${OUT}"/*.png >&2 || true
    exit 1
  fi
fi

BASE_COMMIT_SHA="$(git -C "${ROOT}" rev-parse HEAD 2>/dev/null || echo unknown)"
WORKTREE_DIRTY=false
if ! git -C "${ROOT}" diff-index --quiet HEAD -- 2>/dev/null; then
  WORKTREE_DIRTY=true
fi
TRACKED_DIFF_SHA256="$(git -C "${ROOT}" diff HEAD | shasum -a 256 | awk '{print $1}')"
UNTRACKED_FILES="$(git -C "${ROOT}" ls-files --others --exclude-standard | LC_ALL=C sort)"
UNTRACKED_REGISTER_SHA256="$(printf '%s\n' "${UNTRACKED_FILES}" | shasum -a 256 | awk '{print $1}')"
MANIFEST="${OUT}/capture-manifest.json"

echo "[screenshots] destination=${DEST}"
echo "[screenshots] output=${OUT}"
echo "[screenshots] language=${LANGUAGE}"
echo "[screenshots] base_commit_sha=${BASE_COMMIT_SHA}"
echo "[screenshots] worktree_dirty=${WORKTREE_DIRTY}"
echo "[screenshots] run_stamp=${RUN_STAMP}"

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
  "TEST_RUNNER_HIAIR_SCREENSHOT_RUN_STAMP=${RUN_STAMP}"
BUILD_STATUS=$?
set -e

# Persist xcresult bundle as evidence (temp run dir is removed after manifest write).
if [[ -d "${RESULT_BUNDLE}" ]]; then
  rm -rf "${PERSISTENT_RESULT}"
  cp -R "${RESULT_BUNDLE}" "${PERSISTENT_RESULT}"
fi

ATTACH_DIR="${OUT}/xcresult-attachments"
if command -v xcrun >/dev/null 2>&1 && [[ -d "${RESULT_BUNDLE}" ]]; then
  mkdir -p "${ATTACH_DIR}"
  xcrun xcresulttool export attachments \
    --path "${RESULT_BUNDLE}" \
    --output-path "${ATTACH_DIR}" 2>/dev/null || true
  python3 - <<'PY' "${ATTACH_DIR}" "${OUT}"
import json
import os
import re
import shutil
import sys

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
        src = os.path.join(attach_dir, exported)
        if not os.path.isfile(src):
            src = os.path.join(out_dir, exported)
        if not os.path.isfile(src):
            continue
        base = suggested.split("_0_")[0] if suggested else exported
        base = re.sub(r"[^a-zA-Z0-9._-]", "-", base)
        if not base.endswith(".png"):
            base += ".png"
        dest = os.path.join(out_dir, base)
        shutil.copy2(src, dest)
PY
fi

# Validate exact expected filenames — reject missing, duplicate basenames, unexpected PNG.
python3 - <<'PY' "${OUT}" "${RUN_STAMP}" "${BUILD_STATUS}"
import hashlib
import os
import sys

out_dir, run_stamp, build_status = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
expected = [
    "01-auth.png",
    "01b-onboarding.png",
    "02-dashboard.png",
    "03-planner.png",
    "04-insights.png",
    "05-symptoms.png",
    "06-settings.png",
    "06b-settings-subscription.png",
    "07-paywall.png",
    "07b-paywall-restore.png",
]

pngs = sorted(f for f in os.listdir(out_dir) if f.endswith(".png"))
unexpected = [f for f in pngs if f not in expected]
missing = [f for f in expected if not os.path.isfile(os.path.join(out_dir, f))]
if unexpected:
    raise SystemExit(f"[screenshots] Unexpected PNG files: {unexpected}")
if missing:
    raise SystemExit(f"[screenshots] Missing expected PNG files: {missing}")
if len(pngs) != len(expected):
    raise SystemExit(f"[screenshots] Expected {len(expected)} PNG files, found {len(pngs)}")

stale = []
for name in expected:
    path = os.path.join(out_dir, name)
    mtime = int(os.path.getmtime(path))
    if mtime < run_stamp - 30:
        stale.append(name)
if stale:
    raise SystemExit(f"[screenshots] Stale PNG rejected (older than run): {stale}")
if build_status != 0:
    raise SystemExit(build_status)
PY

if [[ "${BUILD_STATUS}" -ne 0 ]]; then
  echo "[screenshots] xcodebuild exit ${BUILD_STATUS}" >&2
  exit "${BUILD_STATUS}"
fi

# Write provenance manifest (never claim dirty tree as RC source SHA).
python3 - <<'PY' \
  "${MANIFEST}" \
  "${OUT}" \
  "${DEST}" \
  "${LANGUAGE}" \
  "${ACCESSIBILITY_SIZE}" \
  "${REDUCE_MOTION}" \
  "${REDUCE_TRANSPARENCY}" \
  "${BASE_COMMIT_SHA}" \
  "${WORKTREE_DIRTY}" \
  "${TRACKED_DIFF_SHA256}" \
  "${UNTRACKED_REGISTER_SHA256}" \
  "${RUN_STAMP}" \
  "${BUILD_STATUS}" \
  "${PERSISTENT_RESULT}" \
  "${ROOT}"
import hashlib
import json
import os
import platform
import subprocess
import sys
from datetime import datetime, timezone

(
    manifest_path,
    out_dir,
    destination,
    language,
    accessibility_size,
    reduce_motion,
    reduce_transparency,
    base_commit_sha,
    worktree_dirty,
    tracked_diff_sha256,
    untracked_register_sha256,
    run_stamp,
    build_status,
    result_bundle,
    root,
) = sys.argv[1:]

expected = [
    "01-auth.png",
    "01b-onboarding.png",
    "02-dashboard.png",
    "03-planner.png",
    "04-insights.png",
    "05-symptoms.png",
    "06-settings.png",
    "06b-settings-subscription.png",
    "07-paywall.png",
    "07b-paywall-restore.png",
]

files = []
for name in expected:
    path = os.path.join(out_dir, name)
    with open(path, "rb") as handle:
        digest = hashlib.sha256(handle.read()).hexdigest()
    files.append(
        {
            "filename": name,
            "sha256": digest,
            "size_bytes": os.path.getsize(path),
        }
    )

xcresult_sha256 = None
if os.path.isdir(result_bundle):
    hasher = hashlib.sha256()
    for dirpath, _, filenames in sorted(os.walk(result_bundle)):
        for filename in sorted(filenames):
            filepath = os.path.join(dirpath, filename)
            rel = os.path.relpath(filepath, result_bundle).encode("utf-8")
            hasher.update(rel)
            hasher.update(b"\0")
            with open(filepath, "rb") as handle:
                while True:
                    chunk = handle.read(1024 * 1024)
                    if not chunk:
                        break
                    hasher.update(chunk)
    xcresult_sha256 = hasher.hexdigest()

runtime = {}
try:
    sim = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "booted", "-j"],
        text=True,
    )
    runtime["simctl_booted_json"] = json.loads(sim)
except Exception as exc:  # noqa: BLE001
    runtime["simctl_error"] = str(exc)
runtime["platform"] = platform.platform()
runtime["python"] = platform.python_version()

payload = {
    "captured_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "artifact_kind": "ios_store_screenshot_evidence",
    "provenance": {
        "base_commit_sha": base_commit_sha,
        "worktree_dirty": worktree_dirty.lower() == "true",
        "tracked_diff_sha256": tracked_diff_sha256,
        "untracked_register_sha256": untracked_register_sha256,
        "rc_source_sha": base_commit_sha if worktree_dirty.lower() != "true" else None,
        "note": (
            "RC_SOURCE_SHA is null while worktree_dirty=true; use base_commit_sha + diff hashes."
            if worktree_dirty.lower() == "true"
            else "Clean tree: rc_source_sha equals base_commit_sha."
        ),
    },
    "test_configuration": {
        "suite": "HiAirUITests/StoreScreenshotTests",
        "destination": destination,
        "language": language,
        "accessibility_text_size": accessibility_size,
        "reduce_motion": reduce_motion,
        "reduce_transparency": reduce_transparency,
        "xcodebuild_exit_status": int(build_status),
    },
    "device_runtime": runtime,
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
ls -la "${OUT}"/*.png
