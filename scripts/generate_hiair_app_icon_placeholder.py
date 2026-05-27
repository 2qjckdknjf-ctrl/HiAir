#!/usr/bin/env python3
"""Generate placeholder HiAir app icon PNG (1024) for iOS AppIcon.appiconset."""
from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "mobile/ios/HiAir/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
SIZE = 1024


def _chunk(tag: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)


def write_png(path: Path, rgba_rows: list[list[tuple[int, int, int, int]]]) -> None:
    height = len(rgba_rows)
    width = len(rgba_rows[0])
    raw = bytearray()
    for row in rgba_rows:
        raw.append(0)
        for r, g, b, a in row:
            raw.extend((r, g, b, a))
    compressed = zlib.compress(bytes(raw), 9)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", ihdr) + _chunk(b"IDAT", compressed) + _chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def bg_color(y: int) -> tuple[int, int, int]:
    t = y / (SIZE - 1)
    top = (0x0E, 0x12, 0x26)
    bottom = (0x18, 0x1D, 0x38)
    return (
        int(lerp(top[0], bottom[0], t)),
        int(lerp(top[1], bottom[1], t)),
        int(lerp(top[2], bottom[2], t)),
    )


def main() -> None:
    cx, cy = SIZE // 2, int(SIZE * 0.46)
    radius = int(SIZE * 0.22)
    rows: list[list[tuple[int, int, int, int]]] = []
    for y in range(SIZE):
        row: list[tuple[int, int, int, int]] = []
        bg = bg_color(y)
        for x in range(SIZE):
            dx = x - cx
            dy = y - cy
            dist = math.hypot(dx, dy)
            if dist <= radius:
                t = dist / radius
                r = int(lerp(0x5D, 0x8B, t))
                g = int(lerp(0xD5, 0x7B, t))
                b = int(lerp(0xC4, 0xFF, t))
                alpha = int(lerp(240, 120, t))
                row.append((r, g, b, alpha))
            elif dist <= radius * 1.35:
                glow = max(0.0, 1.0 - (dist - radius) / (radius * 0.35))
                r = min(255, bg[0] + int(0x5D * glow * 0.35))
                g = min(255, bg[1] + int(0xD5 * glow * 0.35))
                b = min(255, bg[2] + int(0xC4 * glow * 0.35))
                row.append((r, g, b, 255))
            else:
                row.append((bg[0], bg[1], bg[2], 255))
        rows.append(row)

    # H-wave inside orb
    for y in range(cy - radius // 3, cy + radius // 3):
        for x in range(cx - radius // 2, cx + radius // 2):
            if 0 <= y < SIZE and 0 <= x < SIZE:
                if abs(y - cy) <= 12 and cx - radius // 3 <= x <= cx + radius // 4:
                    rows[y][x] = (0xF0, 0xF4, 0xFF, 220)
                if abs(y - (cy + 18)) <= 10 and cx <= x <= cx + radius // 2:
                    rows[y][x] = (0x8B, 0x7B, 0xFF, 200)

    write_png(OUT, rows)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
