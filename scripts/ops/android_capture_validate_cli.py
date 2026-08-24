#!/usr/bin/env python3
"""CLI for android_capture_validate helpers."""

from __future__ import annotations

import sys

from android_capture_validate import validate_hierarchy


def main(argv: list[str]) -> int:
    if len(argv) < 5:
        print("usage: android_capture_validate.py <hierarchy.xml> <expected_marker> <foreground_package>", file=sys.stderr)
        return 2
    xml_path, marker, fg = argv[1], argv[2], argv[3]
    with open(xml_path, encoding="utf-8") as handle:
        xml_text = handle.read()
    result = validate_hierarchy(xml_text, expected_marker=marker, foreground_package=fg)
    if not result.ok:
        for err in result.errors:
            print(err, file=sys.stderr)
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
