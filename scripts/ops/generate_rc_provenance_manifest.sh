#!/usr/bin/env bash
# Generate RC provenance manifest JSON with payload hash + external file SHA sidecar.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-${ROOT}/docs/release/RC_PROVENANCE_MANIFEST_2026-08-24.json}"
EVIDENCE_RUNS_JSON="${HIAIR_RC_EVIDENCE_RUNS:-}"
SOURCE_TREE_FILE="$(mktemp)"
trap 'rm -f "${SOURCE_TREE_FILE}"' EXIT
python3 "${ROOT}/scripts/ops/provenance_source_tree.py" "${ROOT}" --json > "${SOURCE_TREE_FILE}"

python3 - <<'PY' "${OUT}" "${SOURCE_TREE_FILE}" "${EVIDENCE_RUNS_JSON}" "${ROOT}"
import importlib.util, json, os, sys
from datetime import datetime, timezone

out_path, source_tree_file, evidence_runs_json, root = sys.argv[1:]
_lib_path = os.path.join(root, "scripts", "ops", "provenance_manifest_lib.py")
_spec = importlib.util.spec_from_file_location("provenance_manifest_lib", _lib_path)
_mod = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(_mod)
compute_payload_sha256 = _mod.compute_payload_sha256
file_sha256 = _mod.file_sha256
with open(source_tree_file, encoding="utf-8") as handle:
    source_tree = json.load(handle)

rc_source_sha = source_tree.get("rc_source_sha") or source_tree["head_sha"]

payload = {
    "manifest_kind": "hiair_store_ready_rc_provenance",
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "manifest_generated_from_sha": rc_source_sha,
    "rc_source_sha": rc_source_sha,
    "branch": "cursor/store-ready-hardening-2026-08-22",
    "verdict": "NO-GO / HARDENING IN PROGRESS",
    "hash_model": {
        "file_sha256": "stored only in sibling .sha256 sidecar (full JSON bytes)",
        "manifest_payload_sha256": "SHA-256 of canonical JSON excluding manifest_payload_sha256 and manifest_generated_from_sha",
        "canonicalization": "json.dumps(sort_keys=True, separators=(',', ':'), ensure_ascii=False)",
    },
    "source_tree": {
        "head_sha": source_tree["head_sha"],
        "tracked_worktree_clean": source_tree["tracked_worktree_clean"],
        "untracked_source_inputs": source_tree["untracked_source_inputs"],
        "untracked_evidence_outputs": source_tree["untracked_evidence_outputs"],
        "source_tree_reproducible": source_tree["source_tree_reproducible"],
    },
    "ios": {
        "artifact_type": "simulator_debug_test_evidence",
        "signing_status": "unsigned_simulator_store_screenshots",
    },
    "android": {
        "artifact_type": "aab_release_local",
        "signing_status": "debug_or_dev_release_not_play_uploadable",
        "bundle_path": "mobile/android/app/build/outputs/bundle/release/app-release.aab",
    },
    "evidence_runs": [],
}

if evidence_runs_json and os.path.isfile(evidence_runs_json):
    with open(evidence_runs_json, encoding="utf-8") as handle:
        payload["evidence_runs"] = json.load(handle)

payload["manifest_payload_sha256"] = compute_payload_sha256(payload)

with open(out_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")

digest = file_sha256(out_path)
checksum_path = out_path + ".sha256"
with open(checksum_path, "w", encoding="utf-8") as handle:
    handle.write(digest + "\n")
print(out_path)
print(checksum_path)
print(digest)
PY

python3 "${ROOT}/scripts/ops/provenance_manifest_lib.py" verify "${OUT}" "${ROOT}"
