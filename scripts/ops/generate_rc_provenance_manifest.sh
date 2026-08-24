#!/usr/bin/env bash
# Generate RC provenance manifest JSON using the corrected self-reference model.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-${ROOT}/docs/release/RC_PROVENANCE_MANIFEST_2026-08-24.json}"
EVIDENCE_MANIFEST="${HIAIR_RC_EVIDENCE_MANIFEST:-}"
SOURCE_TREE_FILE="$(mktemp)"
trap 'rm -f "${SOURCE_TREE_FILE}"' EXIT
python3 "${ROOT}/scripts/ops/provenance_source_tree.py" "${ROOT}" --json > "${SOURCE_TREE_FILE}"

python3 - <<'PY' "${OUT}" "${SOURCE_TREE_FILE}" "${EVIDENCE_MANIFEST}" "${ROOT}"
import hashlib, json, os, sys
from datetime import datetime, timezone

out_path, source_tree_file, evidence_manifest, root = sys.argv[1:]
with open(source_tree_file, encoding="utf-8") as handle:
    source_tree = json.load(handle)
generated_from = source_tree["head_sha"]

payload = {
    "manifest_kind": "hiair_store_ready_rc_provenance",
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "manifest_generated_from_sha": generated_from,
    "manifest_file_sha256": None,
    "manifest_containing_commit_sha": None,
    "manifest_containing_commit_sha_note": (
        "Not stored inside this file (self-reference impossible). "
        "Determine after commit via: git log -1 --format=%H -- <this-file>"
    ),
    "source_tree": source_tree,
    "rc_source_sha": source_tree.get("rc_source_sha"),
    "branch": "cursor/store-ready-hardening-2026-08-22",
    "verdict": "NO-GO / HARDENING IN PROGRESS",
    "ios": {
        "artifact_type": "simulator_debug_test_evidence",
        "signing_status": "unsigned_simulator_store_screenshots",
    },
    "android": {
        "artifact_type": "aab_release_local",
        "signing_status": "debug_or_dev_release_not_play_uploadable",
        "bundle_path": "mobile/android/app/build/outputs/bundle/release/app-release.aab",
    },
}

if evidence_manifest and os.path.isfile(evidence_manifest):
    with open(evidence_manifest, encoding="utf-8") as handle:
        payload["ios_screenshot_evidence"] = json.load(handle)

with open(out_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")

digest = hashlib.sha256(open(out_path, "rb").read()).hexdigest()
payload["manifest_file_sha256"] = digest
with open(out_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
digest = hashlib.sha256(open(out_path, "rb").read()).hexdigest()

checksum_path = out_path + ".sha256"
with open(checksum_path, "w", encoding="utf-8") as handle:
    handle.write(digest + "\n")
print(out_path)
print(checksum_path)
print(digest)
PY
