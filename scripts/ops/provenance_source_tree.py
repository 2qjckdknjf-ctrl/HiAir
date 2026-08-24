#!/usr/bin/env python3
"""Compute reproducible source-tree provenance for RC manifests and capture scripts."""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

# Generated evidence outputs — presence does not invalidate source reproducibility.
EVIDENCE_PREFIXES = (".evidence/",)
EVIDENCE_EXACT = {".evidence"}


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def classify_untracked(path: str) -> str:
    if path in EVIDENCE_EXACT or any(path.startswith(p) for p in EVIDENCE_PREFIXES):
        return "evidence_output"
    if path.endswith(".sha256"):
        return "evidence_output"
    lower = path.lower()
    if lower.endswith((
        ".png", ".jpg", ".jpeg", ".xcresult", ".log", ".ipa", ".aab", ".apk", ".deriveddata",
    )):
        return "evidence_output"
    return "source_input"


def source_extensions() -> tuple[str, ...]:
    return (
        ".swift", ".kt", ".kts", ".py", ".sh", ".sql", ".md", ".json", ".xml", ".yml", ".yaml",
        ".gradle", ".properties", ".plist", ".strings", ".xcconfig",
    )


def is_source_input(path: str, kind: str) -> bool:
    if kind != "source_input":
        return False
    if "/" not in path:
        return path.endswith(source_extensions())
    return path.endswith(source_extensions()) or path.startswith(
        ("mobile/", "backend/", "scripts/", "docs/", "infra/", "web/")
    )


def compute(root: Path) -> dict:
    head = git(root, "rev-parse", "HEAD")
    tracked_clean = subprocess.run(
        ["git", "-C", str(root), "diff-index", "--quiet", "HEAD", "--"],
        check=False,
    ).returncode == 0

    tracked_diff_sha256 = hashlib.sha256(git(root, "diff", "HEAD").encode()).hexdigest()
    untracked_all = sorted(git(root, "ls-files", "--others", "--exclude-standard").splitlines())
    untracked_all = [p for p in untracked_all if p]

    by_kind: dict[str, list[str]] = {"source_input": [], "evidence_output": [], "other": []}
    for path in untracked_all:
        kind = classify_untracked(path)
        if is_source_input(path, kind):
            by_kind["source_input"].append(path)
        elif kind == "evidence_output":
            by_kind["evidence_output"].append(path)
        else:
            by_kind["other"].append(path)

    source_inputs = sorted(by_kind["source_input"])
    evidence_outputs = sorted(by_kind["evidence_output"])
    source_tree_reproducible = tracked_clean and len(source_inputs) == 0
    rc_source_sha = head if source_tree_reproducible else None

    return {
        "head_sha": head,
        "tracked_worktree_clean": tracked_clean,
        "tracked_diff_sha256": tracked_diff_sha256,
        "untracked_source_inputs": source_inputs,
        "untracked_evidence_outputs": evidence_outputs,
        "untracked_other": by_kind["other"],
        "source_tree_reproducible": source_tree_reproducible,
        "rc_source_sha": rc_source_sha,
        "note": (
            "manifest_containing_commit_sha is NOT stored inside JSON manifests "
            "(self-reference impossible). Report it externally after git commit."
        ),
    }


def manifest_file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    payload = compute(root)
    if len(sys.argv) > 2 and sys.argv[2] == "--json":
        print(json.dumps(payload, indent=2))
        return
    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    main()
