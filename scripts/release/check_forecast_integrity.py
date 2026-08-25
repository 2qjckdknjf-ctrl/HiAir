#!/usr/bin/env python3
"""Fail if production code reintroduces synthetic forecast or heuristic metrics."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

SCAN_ROOTS = [
    ROOT / "backend" / "app",
    ROOT / "mobile" / "ios" / "HiAir",
    ROOT / "mobile" / "android" / "app" / "src" / "main",
]

SKIP_NAME_PARTS = {
    "/tests/",
    "/HiAirTests/",
    "/HiAirUITests/",
    "/src/test/",
    "/src/androidTest/",
}

FORBIDDEN = [
    ("_project_environment", "synthetic future environment projector"),
    ("_shift_env", "synthetic planner hour shifter"),
    ("pm25 * 1.45", "PM10 inferred from PM2.5"),
    ("temperature_c - 16", "UV inferred from temperature"),
    ("humidity_percent / 100 * 2.8", "wind inferred from humidity"),
    ("uv=4.0", "hardcoded UV fallback"),
    ("wind_speed=2.0", "hardcoded wind fallback"),
    ("heat_wave", "sinusoidal synthetic heat curve"),
    ("traffic_wave", "sinusoidal synthetic traffic curve"),
]


def _iter_files() -> list[Path]:
    files: list[Path] = []
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix.lower() not in {".py", ".swift", ".kt", ".kts"}:
                continue
            rel = path.as_posix()
            if any(part in rel for part in SKIP_NAME_PARTS):
                continue
            files.append(path)
    return files


def _check_android_day_plan_uses_strict_http() -> list[str]:
    path = (
        ROOT
        / "mobile"
        / "android"
        / "app"
        / "src"
        / "main"
        / "java"
        / "com"
        / "hiair"
        / "network"
        / "ApiClient.kt"
    )
    if not path.exists():
        return [f"{path.relative_to(ROOT).as_posix()}: missing"]
    text = path.read_text(encoding="utf-8")
    marker = "fun fetchAirDayPlan"
    idx = text.find(marker)
    if idx < 0:
        return [f"{path.relative_to(ROOT).as_posix()}: fetchAirDayPlan missing"]
    window = text[idx : idx + 350]
    if "requestStrict(" not in window:
        return [
            f"{path.relative_to(ROOT).as_posix()}: fetchAirDayPlan must use requestStrict "
            "(so HTTP 402 premium gating works)"
        ]
    if 'return request("GET"' in window:
        return [
            f"{path.relative_to(ROOT).as_posix()}: fetchAirDayPlan still uses non-strict request()"
        ]
    return []


def main() -> int:
    violations: list[str] = []
    for path in _iter_files():
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        rel = path.relative_to(ROOT).as_posix()
        for needle, reason in FORBIDDEN:
            if needle in text:
                violations.append(f"{rel}: found `{needle}` ({reason})")
    violations.extend(_check_android_day_plan_uses_strict_http())
    if violations:
        print("Forecast integrity: FAIL")
        for item in violations:
            print(f"  {item}")
        return 1
    print("Forecast integrity: PASS (no synthetic production helpers)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
