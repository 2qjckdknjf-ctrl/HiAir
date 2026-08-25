#!/usr/bin/env python3
"""Regression tests for Android capture shelf detection and canonical references."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

OPS = Path(__file__).resolve().parent
ROOT = OPS.parent.parent
FIXTURES = OPS / "fixtures" / "android_capture_shelf"
sys.path.insert(0, str(OPS))

from android_capture_lib import (  # noqa: E402
    ANDROID_VISUAL_CANONICAL_REFERENCES,
    validate_canonical_references,
)
from android_capture_shelf import (  # noqa: E402
    count_bottom_shelf_rows,
    png_pixels,
    shelf_band_detected_in_png,
    trim_bottom_shelf_band,
)


REGRESSION_FIXTURES = (
    "medium-dashboard.app.png",
    "medium-settings.app.png",
    "tablet-landscape-dashboard.app.png",
    "tablet-landscape-planner.app.png",
)


class ShelfRegressionTests(unittest.TestCase):
    def test_fixtures_present(self) -> None:
        for name in REGRESSION_FIXTURES:
            self.assertTrue((FIXTURES / name).is_file(), msg=name)

    def test_untrimmed_fixtures_detect_shelf(self) -> None:
        for name in REGRESSION_FIXTURES:
            path = FIXTURES / name
            self.assertTrue(
                shelf_band_detected_in_png(path),
                msg=f"expected shelf in fixture {name}",
            )

    def test_bottom_shelf_rows_positive_on_fixtures(self) -> None:
        for name in REGRESSION_FIXTURES:
            parsed = png_pixels(FIXTURES / name)
            self.assertIsNotNone(parsed, msg=name)
            width, height, pixels = parsed  # type: ignore[misc]
            rows = count_bottom_shelf_rows(pixels, width, height)
            self.assertGreaterEqual(rows, 8, msg=f"{name} rows={rows}")

    def test_trim_removes_shelf_from_fixture(self) -> None:
        import shutil
        import tempfile

        for name in REGRESSION_FIXTURES:
            with tempfile.TemporaryDirectory() as tmp:
                copy = Path(tmp) / name
                shutil.copy2(FIXTURES / name, copy)
                trimmed_px, changed = trim_bottom_shelf_band(copy)
                self.assertTrue(changed, msg=f"{name} trim unchanged")
                self.assertGreaterEqual(trimmed_px, 8, msg=f"{name} trimmed={trimmed_px}")
                self.assertFalse(
                    shelf_band_detected_in_png(copy),
                    msg=f"shelf remains after trim for {name}",
                )


class CanonicalReferenceContractTests(unittest.TestCase):
    def test_symptoms_use_health_reference(self) -> None:
        self.assertEqual(
            ANDROID_VISUAL_CANONICAL_REFERENCES["phone-symptoms"],
            "docs/design/redesign-v4/references/03-health-deep-glass.png",
        )
        self.assertEqual(
            ANDROID_VISUAL_CANONICAL_REFERENCES["tablet-landscape-symptoms"],
            "docs/design/redesign-v4/references/03-health-deep-glass.png",
        )
        self.assertNotIn("03-symptoms-deep-glass.png", str(ANDROID_VISUAL_CANONICAL_REFERENCES.values()))

    def test_all_canonical_references_exist(self) -> None:
        missing = validate_canonical_references(ROOT)
        self.assertEqual(missing, [], msg=f"missing refs: {missing}")


if __name__ == "__main__":
    raise SystemExit(unittest.main())
