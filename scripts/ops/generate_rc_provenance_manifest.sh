#!/usr/bin/env bash
# Generate RC provenance manifest JSON using the corrected self-reference model.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-${ROOT}/docs/release/RC_PROVENANCE_MANIFEST_2026-08-24.json}"
EVIDENCE_MANIFEST="${HIAIR_RC_EVIDENCE_MANIFEST:-}"
SOURCE_TREE="$(python3 "${ROOT}/scripts/ops/provenance_source_tree.py" "${ROOT}" --json)"
GENERATED_FROM_SHA="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['head_sha'])" "${SOURCE_TREE}")"

python3 - <<'PY' "${OUT}" "${SOURCE_TREE}" "${GENERATED_FROM_SHA}" "${EVIDENCE_MANIFEST}" "${ROOT}"
import hashlib, json, os, sys
from datetime import datetime, timezone

out_path, source_tree_json, generated_from, evidence_manifest, root = sys.argv[1:]
source_tree = json.loads(source_tree_json)

payload = {
    "manifest_kind": "hiair_store_ready_rc_provenance",
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "manifest_generated_from_sha": generated_from,
    "manifest_containing_commit_sha": None,
    "manifest_containing_commit_sha_note": (
        "Not stored inside this file (self-reference impossible). "
        "Determine after commit via: git log -1 --format=%H -- <this-file>"
    ),
    "source_tree": source_tree,
    "rc_source_sha": source_tree.get("rc_source_sha"),
    "branch": "cursor/store-ready-hardening-2026-08-22",
    "verdict": "NO-GO / HARDENING IN PROGRESS",
}

if evidence_manifest and os.path.isfile(evidence_manifest):
    with open(evidence_manifest, encoding="utf-8") as handle:
        payload["ios_screenshot_evidence"] = json.load(handle)

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
