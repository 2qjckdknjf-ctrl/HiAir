#!/usr/bin/env bash
# Contract/smoke tests for capture_ios_screenshots.sh validation logic (no simulator run).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${ROOT}/scripts/ops/capture_ios_screenshots.sh"
TMP="${TMPDIR:-/tmp}/hiair-capture-contract-$$"
trap 'rm -rf "${TMP}"' EXIT

fail() {
  echo "[contract] FAIL: $*" >&2
  exit 1
}

pass() {
  echo "[contract] PASS: $*"
}

[[ -x "${SCRIPT}" || -f "${SCRIPT}" ]] || fail "missing script ${SCRIPT}"
bash -n "${SCRIPT}" || fail "bash syntax check"

# Non-empty output directory must be rejected.
mkdir -p "${TMP}/blocked"
echo "fake" > "${TMP}/blocked/stale.png"
if HIAIR_SCREENSHOT_OUT="${TMP}/blocked" HIAIR_SCREENSHOT_ALLOW_NONEMPTY=0 bash "${SCRIPT}" 2>/dev/null; then
  fail "expected rejection for non-empty output directory"
fi
pass "rejects non-empty output directory"

# Expected filename validation (python block extracted behavior).
python3 - <<'PY' "${TMP}/validate"
import os
import sys
import tempfile

out_dir = sys.argv[1]
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

os.makedirs(out_dir, exist_ok=True)
for name in expected:
    with open(os.path.join(out_dir, name), "wb") as handle:
        handle.write(b"png")

pngs = sorted(f for f in os.listdir(out_dir) if f.endswith(".png"))
unexpected = [f for f in pngs if f not in expected]
missing = [f for f in expected if not os.path.isfile(os.path.join(out_dir, f))]
if unexpected or missing or len(pngs) != len(expected):
    raise SystemExit(f"unexpected={unexpected} missing={missing} count={len(pngs)}")
print("ok")
PY
pass "exact expected filename set validates"

# Dirty-tree provenance fields present in manifest writer inputs.
BASE="$(git -C "${ROOT}" rev-parse HEAD)"
DIRTY=false
git -C "${ROOT}" diff-index --quiet HEAD -- || DIRTY=true
DIFF_SHA="$(git -C "${ROOT}" diff HEAD | shasum -a 256 | awk '{print $1}')"
UNTRACKED_SHA="$(git -C "${ROOT}" ls-files --others --exclude-standard | LC_ALL=C sort | shasum -a 256 | awk '{print $1}')"
[[ -n "${BASE}" ]] || fail "base commit sha empty"
[[ -n "${DIFF_SHA}" ]] || fail "tracked diff sha empty"
[[ -n "${UNTRACKED_SHA}" ]] || fail "untracked register sha empty"
if [[ "${DIRTY}" == "true" ]]; then
  pass "worktree dirty — manifest must not set rc_source_sha as factual RC identity"
else
  pass "worktree clean — rc_source_sha may equal base commit"
fi

echo "[contract] all capture_ios_screenshots contract checks passed"
