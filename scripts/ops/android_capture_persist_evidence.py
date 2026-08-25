#!/usr/bin/env python3
"""Persist Android targeted-visual capture evidence with raw/app PNG separation."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path
from struct import unpack

from android_capture_lib import parse_app_window_frame
from android_capture_shelf import (
    post_crop_shelf_scan,
    shelf_band_detected_in_png,
    trim_bottom_shelf_band,
)


def png_size(path: Path) -> tuple[int, int] | None:
    try:
        data = path.read_bytes()
        w, h = unpack(">II", data[16:24])
        return w, h
    except Exception:
        return None


def sha256_file(path: Path) -> str | None:
    if not path.exists() or path.stat().st_size == 0:
        return None
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def marker_bounds(xml_text: str, desc: str) -> tuple[int, int, int, int] | None:
    pattern = (
        rf'content-desc="{re.escape(desc)}"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
    )
    match = re.search(pattern, xml_text)
    if not match:
        return None
    return tuple(map(int, match.groups()))


def largest_app_bounds(xml_text: str) -> tuple[int, int, int, int] | None:
    best = None
    for match in re.finditer(
        r'package="com\.hiair"[\s\S]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        xml_text,
    ):
        x1, y1, x2, y2 = map(int, match.groups())
        area = max(0, x2 - x1) * max(0, y2 - y1)
        if best is None or area > best[0]:
            best = (area, x1, y1, x2, y2)
    if best is None:
        return None
    return best[1:]


def hierarchy_app_chrome_bounds(xml_text: str, raw: tuple[int, int]) -> tuple[int, int, int, int] | None:
    """Resolve app chrome bounds from geometry markers; never crop above y=0."""
    raw_w, raw_h = raw
    tops: list[int] = [0]
    bottoms: list[int] = []
    for desc in (
        "geometry.navigation.bar",
        "geometry.navigation.row",
        "geometry.layout.content_frame",
    ):
        bounds = marker_bounds(xml_text, desc)
        if bounds:
            bottoms.append(bounds[3])
    for match in re.finditer(
        r'content-desc="((?:screen\.[a-z]+\.root)|(?:geometry\.layout\.content_frame)|(?:geometry\.navigation\.(?:bar|row)))"'
        r'[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        xml_text,
    ):
        tops.append(int(match.group(2)))
        bottoms.append(int(match.group(5)))
    if not bottoms:
        return largest_app_bounds(xml_text)
    y1 = min(tops) if tops else 0
    y1 = 0  # preserve title/safe-area inset
    y2 = max(bottoms)
    x1, x2 = 0, raw_w
    if y2 <= y1 + 32:
        return largest_app_bounds(xml_text)
    return (x1, y1, x2, min(y2, raw_h))


def resolve_crop_bounds(
    xml_text: str,
    raw: tuple[int, int],
    window_dump: str = "",
) -> tuple[tuple[int, int, int, int] | None, str]:
    raw_w, raw_h = raw
    hierarchy_bounds = hierarchy_app_chrome_bounds(xml_text, raw) if xml_text else None
    dumpsys_bounds = parse_app_window_frame(window_dump) if window_dump else None

    if hierarchy_bounds and dumpsys_bounds:
        hx1, hy1, hx2, hy2 = hierarchy_bounds
        dx1, dy1, dx2, dy2 = dumpsys_bounds
        merged = (
            0,
            0,
            min(raw_w, max(hx2, dx2)),
            min(raw_h, max(hy2, dy2)),
        )
        return merged, "hierarchy+dumpsys_merged"

    if hierarchy_bounds:
        x1, y1, x2, y2 = hierarchy_bounds
        return (0, 0, min(x2, raw_w), min(y2, raw_h)), "hierarchy_app_chrome"

    if dumpsys_bounds:
        x1, y1, x2, y2 = dumpsys_bounds
        return (max(0, x1), 0, min(x2, raw_w), min(y2, raw_h)), "dumpsys_window_frame"

    if xml_text:
        largest = largest_app_bounds(xml_text)
        if largest:
            x1, y1, x2, y2 = largest
            return (max(0, x1), 0, min(x2, raw_w), min(y2, raw_h)), "hierarchy_largest_package"

    return None, "none"


def crop_with_sips(src: Path, dst: Path, x1: int, y1: int, x2: int, y2: int) -> bool:
    w = x2 - x1
    h = y2 - y1
    if w <= 0 or h <= 0:
        return False
    result = subprocess.run(
        [
            "sips",
            "-c",
            str(h),
            str(w),
            str(src),
            "--cropOffset",
            str(y1),
            str(x1),
            "--out",
            str(dst),
        ],
        capture_output=True,
        text=True,
    )
    return result.returncode == 0 and dst.exists() and dst.stat().st_size > 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--shot-id", required=True)
    parser.add_argument("--status", required=True)
    parser.add_argument("--png", required=True, help="Path to raw screencap PNG")
    parser.add_argument("--xml", required=True)
    parser.add_argument("--logcat", required=True)
    parser.add_argument("--window-dump", default="")
    parser.add_argument("--reject-reason", default="")
    parser.add_argument("--foreground", default="")
    parser.add_argument("--pid", default="")
    parser.add_argument("--apk-sha256", default="")
    parser.add_argument("--source-sha", default="")
    parser.add_argument("--dirty-hash", default="")
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    raw_png = Path(args.png)
    xml = Path(args.xml)
    logcat = Path(args.logcat)
    window_dump_path = Path(args.window_dump) if args.window_dump else None
    fail_dir = out_dir / "failures" / args.shot_id
    fail_dir.mkdir(parents=True, exist_ok=True)

    shot_id = args.shot_id
    raw_dest = out_dir / f"{shot_id}.raw.png"
    app_dest = out_dir / f"{shot_id}.app.png"

    if raw_png.resolve() != raw_dest.resolve() and raw_png.exists():
        shutil.copy2(raw_png, raw_dest)
    elif not raw_dest.exists() and raw_png.exists():
        shutil.copy2(raw_png, raw_dest)

    xml_text = xml.read_text(errors="ignore") if xml.exists() else ""
    window_dump = window_dump_path.read_text(errors="ignore") if window_dump_path and window_dump_path.exists() else ""
    markers = sorted(set(re.findall(r"(?:store|screen|geometry)\.[a-z0-9_.]+", xml_text)))
    raw = png_size(raw_dest)
    bounds, bounds_method = resolve_crop_bounds(xml_text, raw, window_dump) if raw else (None, "none")

    shelf_reasons: list[str] = []
    crop_applied = False
    final_dimensions = list(raw) if raw else None
    top_trim_px = 0
    bottom_trim_px = 0

    if bounds and raw:
        x1, y1, x2, y2 = bounds
        raw_w, raw_h = raw
        top_trim_px = y1
        needs_crop = (raw_h - y2) > 4 or (raw_w - x2) > 4 or x1 > 4 or y1 > 4
        if needs_crop and (x2 - x1) > 32 and (y2 - y1) > 32:
            if crop_with_sips(raw_dest, app_dest, x1, y1, x2, y2):
                crop_applied = True
                final_dimensions = [x2 - x1, y2 - y1]
            else:
                shelf_reasons.append("crop_failed")
                shutil.copy2(raw_dest, app_dest)
        else:
            shutil.copy2(raw_dest, app_dest)
    elif raw_dest.exists():
        shutil.copy2(raw_dest, app_dest)

    shelf_trim_px = 0
    post_crop: dict[str, object] = {"detected": False, "bottom_trim_px": 0, "reasons": []}
    if app_dest.exists():
        for _ in range(4):
            trimmed, changed = trim_bottom_shelf_band(app_dest)
            if not changed:
                break
            shelf_trim_px += trimmed
            bottom_trim_px += trimmed
        post_crop = post_crop_shelf_scan(app_dest)
        if post_crop.get("detected"):
            shelf_reasons.extend(post_crop.get("reasons", []))  # type: ignore[arg-type]
        elif shelf_band_detected_in_png(app_dest):
            shelf_reasons.append("launcher_shelf_in_app_png")
        final = png_size(app_dest)
        if final:
            final_dimensions = list(final)

    status = args.status
    reject_reason = args.reject_reason or None
    if shelf_reasons and status == "PASS":
        status = "FAIL"
        reject_reason = reject_reason or f"shelf_detected:{','.join(shelf_reasons)}"

    dumpsys_bounds = None
    parsed_frame = parse_app_window_frame(window_dump) if window_dump else None
    if parsed_frame:
        x1, y1, x2, y2 = parsed_frame
        dumpsys_bounds = {"left": x1, "top": y1, "right": x2, "bottom": y2}

    meta = {
        "shot_id": shot_id,
        "status": status,
        "reject_reason": reject_reason,
        "foreground": args.foreground or None,
        "pid": args.pid or None,
        "markers_found": markers,
        "apk_sha256": args.apk_sha256 or None,
        "source_sha": args.source_sha or None,
        "dirty_tree_hash": args.dirty_hash or None,
        "raw_screenshot_path": str(raw_dest.name),
        "app_screenshot_path": str(app_dest.name),
        "raw_screenshot_dimensions": list(raw) if raw else None,
        "app_window_bounds": None,
        "dumpsys_window_bounds": dumpsys_bounds,
        "bounds_method": bounds_method,
        "crop_applied": crop_applied,
        "final_crop_bounds": None,
        "final_dimensions": final_dimensions,
        "launcher_shelf_excluded": not bool(shelf_reasons) if app_dest.exists() else None,
        "shelf_detection": {
            "detected": bool(shelf_reasons),
            "reasons": shelf_reasons,
            "top_trim_px": top_trim_px,
            "bottom_trim_px": bottom_trim_px,
            "post_crop_shelf_trim_px": shelf_trim_px,
            "post_crop_scan": post_crop,
        },
        "sha256": {
            "raw_png": sha256_file(raw_dest),
            "app_png": sha256_file(app_dest),
        },
    }

    if bounds:
        x1, y1, x2, y2 = bounds
        meta["app_window_bounds"] = {"left": x1, "top": y1, "right": x2, "bottom": y2}
        meta["final_crop_bounds"] = {
            "left": x1,
            "top": y1,
            "right": x2,
            "bottom": y2 - shelf_trim_px if shelf_trim_px else y2,
        }

    meta_path = out_dir / f"{shot_id}.capture_meta.json"
    meta_path.write_text(json.dumps(meta, indent=2) + "\n")

    if status != "PASS":
        (fail_dir / "failure_manifest.json").write_text(json.dumps(meta, indent=2) + "\n")
        if raw_dest.exists():
            shutil.copy2(raw_dest, fail_dir / f"{shot_id}.raw.png")
        if app_dest.exists():
            shutil.copy2(app_dest, fail_dir / f"{shot_id}.app.png")
        if xml.exists():
            shutil.copy2(xml, fail_dir / "hierarchy.xml")
        if logcat.exists():
            shutil.copy2(logcat, fail_dir / "logcat.txt")
        if window_dump_path and window_dump_path.exists():
            shutil.copy2(window_dump_path, fail_dir / "window_dump.txt")
        shutil.copy2(meta_path, fail_dir / "capture_meta.json")

    print(json.dumps({"ok": True, "meta": str(meta_path), "status": status}))
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
