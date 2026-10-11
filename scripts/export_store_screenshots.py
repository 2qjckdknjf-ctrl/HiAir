#!/usr/bin/env python3
"""Export named PNGs from a StoreScreenshotTests xcresult."""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: export_store_screenshots.py <xcresult> <outdir>", file=sys.stderr)
        return 2
    xcresult = Path(sys.argv[1])
    outdir = Path(sys.argv[2])
    tmp = outdir / "_export"
    if tmp.exists():
        shutil.rmtree(tmp)
    tmp.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "xcrun",
            "xcresulttool",
            "export",
            "attachments",
            "--path",
            str(xcresult),
            "--output-path",
            str(tmp),
        ],
        check=False,
    )
    manifest = tmp / "manifest.json"
    if not manifest.exists():
        print("missing manifest", file=sys.stderr)
        return 1
    data = json.loads(manifest.read_text())
    outdir.mkdir(parents=True, exist_ok=True)
    for att in data[0]["attachments"]:
        src = tmp / att["exportedFileName"]
        name = att["suggestedHumanReadableName"].split("_0_")[0] + ".png"
        shutil.copy2(src, outdir / name)
        print(name, src.stat().st_size)
    shutil.rmtree(tmp)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
