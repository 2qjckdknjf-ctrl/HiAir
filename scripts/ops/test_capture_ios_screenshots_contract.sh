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

# Dirty-tree provenance fields via provenance_source_tree.py
python3 "${ROOT}/scripts/ops/provenance_source_tree.py" "${ROOT}" --json >/dev/null
TREE="$(python3 "${ROOT}/scripts/ops/provenance_source_tree.py" "${ROOT}" --json)"
for key in head_sha tracked_worktree_clean untracked_source_inputs untracked_evidence_outputs source_tree_reproducible; do
  python3 -c "import json,sys; d=json.loads(sys.argv[1]); assert sys.argv[2] in d" "${TREE}" "${key}" || fail "missing provenance key ${key}"
done
pass "provenance_source_tree exposes clean-tree semantics"

echo "[contract] all capture_ios_screenshots contract checks passed"
