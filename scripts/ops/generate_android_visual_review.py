#!/usr/bin/env python3
"""Generate visual-review.json for Android targeted visual evidence."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

from android_capture_lib import (
    ANDROID_VISUAL_CANONICAL_REFERENCES,
    build_visual_review_template,
    validate_canonical_references,
    visual_review_is_complete,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--manifest", default="manifest.json")
    parser.add_argument("--prior-review", default=None)
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    repo_root = Path(__file__).resolve().parents[2]
    missing = validate_canonical_references(repo_root)
    if missing:
        raise SystemExit(f"missing canonical references: {missing}")

    manifest_path = out_dir / args.manifest
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    semantic_pass = sum(1 for s in manifest.get("shots", []) if s.get("status") == "PASS")
    total = len(ANDROID_VISUAL_CANONICAL_REFERENCES)

    rel_manifest = str(manifest_path.relative_to(repo_root)) if manifest_path.is_relative_to(repo_root) else str(manifest_path)
    out_path = out_dir / "visual-review.json"
    if out_path.exists():
        existing = json.loads(out_path.read_text())
        if visual_review_is_complete(existing):
            print(json.dumps({"ok": True, "path": str(out_path), "skipped": "complete_review_exists"}))
            return 0

    payload = build_visual_review_template(
        evidence_dir=str(out_dir.relative_to(repo_root)) if out_dir.is_relative_to(repo_root) else str(out_dir),
        manifest_path=rel_manifest,
        prior_review=args.prior_review,
    )
    payload["semantic_gate"] = f"{semantic_pass}/{total} PASS" if semantic_pass == total else f"{semantic_pass}/{total}"
    payload["generated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    out_path.write_text(json.dumps(payload, indent=2) + "\n")
    print(json.dumps({"ok": True, "path": str(out_path)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
