#!/usr/bin/env python3
"""RC provenance manifest canonicalization and verification helpers."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from copy import deepcopy
from typing import Any

# Fields excluded from manifest_payload_sha256 (not part of signed payload semantics).
PAYLOAD_EXCLUDED_TOP_LEVEL = frozenset(
    {
        "manifest_payload_sha256",
        "manifest_generated_from_sha",
    }
)


def canonical_json_bytes(obj: Any) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def payload_view(manifest: dict[str, Any]) -> dict[str, Any]:
    view = deepcopy(manifest)
    for key in PAYLOAD_EXCLUDED_TOP_LEVEL:
        view.pop(key, None)
    return view


def compute_payload_sha256(manifest: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_json_bytes(payload_view(manifest))).hexdigest()


def file_sha256(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def read_sidecar(path: str) -> str:
    with open(path, encoding="utf-8") as handle:
        return handle.read().strip()


def git_rev_parse(repo: str, ref: str) -> str:
    return subprocess.check_output(
        ["git", "-C", repo, "rev-parse", ref],
        text=True,
    ).strip()


def verify_manifest(path: str, repo: str) -> list[str]:
    errors: list[str] = []
    if not os.path.isfile(path):
        return [f"missing manifest: {path}"]

    if "manifest_file_sha256" in open(path, encoding="utf-8").read():
        errors.append("manifest must not contain manifest_file_sha256 (use .sha256 sidecar only)")

    with open(path, encoding="utf-8") as handle:
        manifest = json.load(handle)

    if manifest.get("manifest_containing_commit_sha"):
        errors.append("manifest must not contain manifest_containing_commit_sha (external only)")

    sidecar = path + ".sha256"
    if not os.path.isfile(sidecar):
        errors.append(f"missing sidecar: {sidecar}")
    else:
        expected = read_sidecar(sidecar)
        actual = file_sha256(path)
        if expected != actual:
            errors.append(f"sidecar mismatch expected={expected} actual={actual}")

    payload_hash = compute_payload_sha256(manifest)
    embedded = manifest.get("manifest_payload_sha256")
    if not embedded:
        errors.append("missing manifest_payload_sha256")
    elif embedded != payload_hash:
        errors.append(f"payload hash mismatch embedded={embedded} computed={payload_hash}")

    rc_source = manifest.get("rc_source_sha")
    generated_from = manifest.get("manifest_generated_from_sha")
    if not rc_source:
        errors.append("missing rc_source_sha")
    if not generated_from:
        errors.append("missing manifest_generated_from_sha")
    elif rc_source and generated_from != rc_source:
        errors.append(
            f"manifest_generated_from_sha must equal rc_source_sha ({generated_from} != {rc_source})"
        )

    if rc_source:
        try:
            git_rev_parse(repo, rc_source)
        except subprocess.CalledProcessError:
            errors.append(f"rc_source_sha not found in git: {rc_source}")

        if generated_from:
            try:
                diff = subprocess.check_output(
                    ["git", "-C", repo, "diff", "--quiet", f"{rc_source}..{generated_from}"],
                )
                _ = diff  # quiet success means no diff only when same commit
            except subprocess.CalledProcessError:
                # diff exits 1 when trees differ — rc_source must be ancestor of generated_from
                try:
                    subprocess.check_call(
                        ["git", "-C", repo, "merge-base", "--is-ancestor", rc_source, generated_from],
                    )
                except subprocess.CalledProcessError:
                    errors.append("rc_source_sha is not an ancestor of manifest_generated_from_sha")

    return errors


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: provenance_manifest_lib.py verify <manifest.json> [repo]", file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "verify":
        path = argv[2]
        repo = argv[3] if len(argv) > 3 else os.path.dirname(os.path.dirname(os.path.dirname(path)))
        errors = verify_manifest(path, repo)
        if errors:
            for err in errors:
                print(f"ERROR: {err}", file=sys.stderr)
            return 1
        print("OK")
        return 0
    if cmd == "payload-hash":
        with open(argv[2], encoding="utf-8") as handle:
            manifest = json.load(handle)
        print(compute_payload_sha256(manifest))
        return 0
    print(f"unknown command: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
