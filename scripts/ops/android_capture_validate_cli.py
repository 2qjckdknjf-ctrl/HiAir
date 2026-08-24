#!/usr/bin/env python3
"""CLI for android_capture_validate helpers."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from android_capture_validate import validate_hierarchy


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate Android UI hierarchy for store screenshot semantic gates.",
    )
    parser.add_argument("hierarchy_xml", type=Path, help="Path to uiautomator hierarchy XML")
    parser.add_argument("expected_marker", help="Expected screen root content-desc marker")
    parser.add_argument(
        "foreground_package",
        help="Observed foreground package from dumpsys (not hardcoded)",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv[1:] if argv else None)
    xml_text = args.hierarchy_xml.read_text(encoding="utf-8")
    result = validate_hierarchy(
        xml_text,
        expected_marker=args.expected_marker,
        foreground_package=args.foreground_package,
    )
    if not result.ok:
        for err in result.errors:
            print(err, file=sys.stderr)
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
