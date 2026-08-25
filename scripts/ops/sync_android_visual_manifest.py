#!/usr/bin/env python3
"""Sync visual-review.json into targeted-visual manifest.json."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from android_capture_lib import sync_visual_review_to_manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--manifest", default="manifest.json")
    parser.add_argument("--review", default="visual-review.json")
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    manifest_path = out_dir / args.manifest
    review_path = out_dir / args.review
    if not manifest_path.is_file():
        raise SystemExit(f"missing manifest: {manifest_path}")
    if not review_path.is_file():
        raise SystemExit(f"missing visual review: {review_path}")

    manifest = json.loads(manifest_path.read_text())
    review = json.loads(review_path.read_text())
    sync_visual_review_to_manifest(manifest, review)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"ok": True, "manifest": str(manifest_path), "visual_gate": manifest.get("visual_review")}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
