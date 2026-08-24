#!/usr/bin/env python3
"""Reclassify existing Android capture manifests as visual FAIL / not RC evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path

OPS = Path(__file__).resolve().parent
sys.path.insert(0, str(OPS))

from android_capture_lib import compute_aggregate_status, write_manifest  # noqa: E402

RUNS = (
    Path(".evidence/android-screenshots/2026-08-24-phone-en-v6"),
    Path(".evidence/android-screenshots/2026-08-24-tablet-en-v2"),
)

FINDINGS = (
    "SEMANTIC PASS / VISUAL FAIL / NOT RC EVIDENCE — manual V4 review 2026-08-24",
)


def reclassify(manifest_path: Path) -> None:
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    screens = payload.get("screens", [])
    for screen in screens:
        screen["visual_review_result"] = "FAIL"
        screen["visual_findings"] = list(screen.get("visual_findings", [])) + list(FINDINGS)
    payload["classification"] = "SEMANTIC PASS / VISUAL FAIL / NOT RC EVIDENCE"
    payload["rc_evidence"] = False
    payload["source_tree_reproducible"] = False
    overall, semantic, visual = compute_aggregate_status(
        screens=screens,
        semantic_capture_ok=True,
        source_tree=payload.get("provenance"),
        rc_source_sha=payload.get("rc_source_sha"),
    )
    payload["status"] = overall
    payload["semantic_validation"] = semantic
    payload["visual_review_result"] = visual
    write_manifest(manifest_path, payload)
    print(f"updated {manifest_path} -> status={overall}")


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    for rel in RUNS:
        manifest = root / rel / "capture-manifest.json"
        if not manifest.exists():
            print(f"skip missing {manifest}", file=sys.stderr)
            continue
        reclassify(manifest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
