#!/usr/bin/env bash
# Contract test for RC provenance manifest hashing semantics.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="${ROOT}/scripts/ops/provenance_manifest_lib.py"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

MANIFEST="${TMP}/sample-rc-manifest.json"
HEAD_SHA="$(git -C "${ROOT}" rev-parse HEAD)"
cat > "${MANIFEST}" <<EOF
{
  "manifest_kind": "hiair_store_ready_rc_provenance",
  "generated_at": "2026-08-24T12:00:00Z",
  "manifest_generated_from_sha": "${HEAD_SHA}",
  "rc_source_sha": "${HEAD_SHA}",
  "branch": "cursor/store-ready-hardening-2026-08-22",
  "verdict": "NO-GO / HARDENING IN PROGRESS",
  "hash_model": {},
  "source_tree": {"head_sha": "${HEAD_SHA}", "tracked_worktree_clean": true, "untracked_source_inputs": [], "untracked_evidence_outputs": [], "source_tree_reproducible": true},
  "evidence_runs": []
}
EOF

python3 - <<PY
import importlib.util, json, sys
lib_path = "${LIB}"
spec = importlib.util.spec_from_file_location("provenance_manifest_lib", lib_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
path = "${MANIFEST}"
with open(path, encoding="utf-8") as handle:
    manifest = json.load(handle)
manifest["manifest_payload_sha256"] = mod.compute_payload_sha256(manifest)
with open(path, "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, indent=2)
    handle.write("\n")
digest = mod.file_sha256(path)
with open(path + ".sha256", "w", encoding="utf-8") as handle:
    handle.write(digest + "\n")
PY

python3 "${LIB}" verify "${MANIFEST}" "${ROOT}"

HASH1="$(python3 "${LIB}" payload-hash "${MANIFEST}")"
HASH2="$(python3 "${LIB}" payload-hash "${MANIFEST}")"
[[ "${HASH1}" == "${HASH2}" ]] || { echo "payload hash not reproducible" >&2; exit 1; }

if grep -q manifest_file_sha256 "${MANIFEST}"; then
  echo "manifest_file_sha256 must not appear in JSON" >&2
  exit 1
fi

echo "[provenance-contract] OK"
