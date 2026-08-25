#!/usr/bin/env python3
"""Shelf/launcher band detection for Android capture evidence."""

from __future__ import annotations

from pathlib import Path
from struct import pack, unpack


def png_size(path: Path) -> tuple[int, int] | None:
    try:
        data = path.read_bytes()
        w, h = unpack(">II", data[16:24])
        return w, h
    except Exception:
        return None


def _paeth_predictor(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def decode_png_rgba(path: Path) -> tuple[int, int, list[tuple[int, int, int, int]]] | None:
    try:
        import zlib

        data = path.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            return None
        width, height = unpack(">II", data[16:24])
        offset = 8
        idat_chunks: list[bytes] = []
        while offset < len(data):
            length = unpack(">I", data[offset : offset + 4])[0]
            chunk_type = data[offset + 4 : offset + 8]
            chunk = data[offset + 8 : offset + 8 + length]
            offset += 12 + length
            if chunk_type == b"IDAT":
                idat_chunks.append(chunk)
            elif chunk_type == b"IEND":
                break
        if not idat_chunks:
            return None
        inflated = zlib.decompress(b"".join(idat_chunks))
        pixels: list[tuple[int, int, int, int]] = []
        previous = bytes(width * 4)
        pos = 0
        for _ in range(height):
            filter_type = inflated[pos]
            pos += 1
            row = bytearray(inflated[pos : pos + width * 4])
            pos += width * 4
            current = bytearray(width * 4)
            for i in range(width * 4):
                raw = row[i]
                left = current[i - 4] if i >= 4 else 0
                up = previous[i]
                up_left = previous[i - 4] if i >= 4 else 0
                if filter_type == 0:
                    current[i] = raw
                elif filter_type == 1:
                    current[i] = (raw + left) & 0xFF
                elif filter_type == 2:
                    current[i] = (raw + up) & 0xFF
                elif filter_type == 3:
                    current[i] = (raw + ((left + up) // 2)) & 0xFF
                elif filter_type == 4:
                    current[i] = (raw + _paeth_predictor(left, up, up_left)) & 0xFF
                else:
                    current[i] = raw
            for i in range(0, width * 4, 4):
                pixels.append(tuple(current[i : i + 4]))
            previous = bytes(current)
        return width, height, pixels
    except Exception:
        return None


def png_pixels(path: Path) -> tuple[int, int, list[int]] | None:
    decoded = decode_png_rgba(path)
    if decoded is None:
        return None
    width, height, rgba = decoded
    luminance = []
    for r, g, b, a in rgba:
        if a == 0:
            luminance.append(255)
        else:
            luminance.append(int(0.2126 * r + 0.7152 * g + 0.0722 * b))
    return width, height, luminance


def write_png_rgba(path: Path, width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> bool:
    try:
        import zlib

        def chunk(tag: bytes, payload: bytes) -> bytes:
            crc = zlib.crc32(tag + payload) & 0xFFFFFFFF
            return pack(">I", len(payload)) + tag + payload + pack(">I", crc)

        ihdr = pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
        raw = bytearray()
        for y in range(height):
            raw.append(0)
            for x in range(width):
                r, g, b, a = pixels[y * width + x]
                raw.extend((r, g, b, a))
        compressed = zlib.compress(bytes(raw), level=6)
        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
        path.write_bytes(png)
        return True
    except Exception:
        return False


def crop_png_remove_bottom(src: Path, dst: Path, trim_rows: int) -> bool:
    decoded = decode_png_rgba(src)
    if decoded is None or trim_rows <= 0:
        return False
    width, height, pixels = decoded
    new_height = height - trim_rows
    if new_height <= 0:
        return False
    trimmed = pixels[: width * new_height]
    return write_png_rgba(dst, width, new_height, trimmed)


def row_shelf_signature(row: list[int]) -> dict[str, float]:
    if not row:
        return {"mean": 0.0, "bright_ratio": 0.0, "colorful": 0.0, "dark_ratio": 0.0}
    mean_lum = sum(row) / len(row)
    bright_ratio = sum(1 for v in row if v >= 230) / len(row)
    colorful = sum(1 for v in row if 40 < v < 235)
    dark_ratio = sum(1 for v in row if v < 80) / len(row)
    return {
        "mean": mean_lum,
        "bright_ratio": bright_ratio,
        "colorful": float(colorful),
        "dark_ratio": dark_ratio,
    }


def is_shelf_row(row: list[int]) -> bool:
    stats = row_shelf_signature(row)
    mean_lum = stats["mean"]
    bright_ratio = stats["bright_ratio"]
    colorful = stats["colorful"]
    width = len(row)
    if mean_lum >= 240 and bright_ratio >= 0.92:
        return True
    if mean_lum >= 215 and bright_ratio >= 0.75:
        return True
    if mean_lum >= 200 and bright_ratio >= 0.65 and colorful >= max(24, width // 100):
        return True
    return False


def is_launcher_icon_row(row: list[int]) -> bool:
    """White shelf row with sparse colorful launcher icon pixels."""
    stats = row_shelf_signature(row)
    width = len(row)
    if stats["mean"] < 200 or stats["bright_ratio"] < 0.55:
        return False
    colorful = int(stats["colorful"])
    return colorful >= max(16, width // 120)


def count_bottom_shelf_rows(pixels: list[int], width: int, height: int) -> int:
    trim = 0
    for y in range(height - 1, -1, -1):
        row = pixels[y * width : (y + 1) * width]
        if is_shelf_row(row) or is_launcher_icon_row(row):
            trim += 1
        else:
            break
    return trim


def shelf_band_detected_in_png(path: Path, *, scan_rows: int = 96) -> bool:
    parsed = png_pixels(path)
    if parsed is None:
        return False
    width, height, pixels = parsed
    if width <= 0 or height <= 0:
        return False
    bottom_trim = count_bottom_shelf_rows(pixels, width, height)
    if bottom_trim >= 8:
        return True
    start_row = max(0, height - scan_rows)
    for y in range(height - 1, start_row - 1, -1):
        row = pixels[y * width : (y + 1) * width]
        if is_launcher_icon_row(row):
            return True
        if is_shelf_row(row) and row_shelf_signature(row)["bright_ratio"] >= 0.85:
            return True
    return False


def trim_bottom_shelf_band(path: Path) -> tuple[int, bool]:
    """Trim contiguous shelf/launcher rows from the bottom edge."""
    parsed = png_pixels(path)
    if parsed is None:
        return 0, False
    width, height, pixels = parsed
    trim = count_bottom_shelf_rows(pixels, width, height)
    if trim < 4:
        return 0, False
    trimmed = path.with_name(path.stem + ".trim.png")
    if crop_png_remove_bottom(path, trimmed, trim):
        trimmed.replace(path)
        return trim, True
    return 0, False


def crop_png_bottom(src: Path, dst: Path, trim_rows: int) -> bool:
    return crop_png_remove_bottom(src, dst, trim_rows)


def post_crop_shelf_scan(path: Path) -> dict[str, object]:
    parsed = png_pixels(path)
    if parsed is None:
        return {"detected": False, "bottom_trim_px": 0, "reasons": []}
    width, height, pixels = parsed
    bottom_trim = count_bottom_shelf_rows(pixels, width, height)
    reasons: list[str] = []
    if bottom_trim >= 8:
        reasons.append(f"bottom_shelf_rows:{bottom_trim}")
    if shelf_band_detected_in_png(path):
        reasons.append("launcher_shelf_in_app_png")
    return {
        "detected": bool(reasons),
        "bottom_trim_px": bottom_trim,
        "reasons": reasons,
    }
