#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


REQUIRED_LINES = [
    "Backend lead: `DONE`",
    "Mobile lead: `DONE`",
    "DevOps/SRE: `DONE`",
    "Product/QA/Release manager: `DONE`",
]


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate release sign-off document.")
    parser.add_argument(
        "--file",
        default="docs/_operator/release-signoff-template.md",
        help="Path to release sign-off markdown file.",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[2]
    target = Path(args.file)
    if not target.is_absolute():
        target = root / target

    if not target.exists():
        print(f"[MISSING] Sign-off file not found: {target}")
        return 1

    content = target.read_text(encoding="utf-8")
    missing = [line for line in REQUIRED_LINES if line not in content]
    if missing:
        print("[BLOCKED] Sign-off is incomplete. Missing markers:")
        for line in missing:
            print(f"- {line}")
        return 1

    print("[DONE] Sign-off file contains all required DONE markers.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
