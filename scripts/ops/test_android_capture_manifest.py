#!/usr/bin/env python3
"""Unit tests for Android capture manifest aggregate status."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

OPS = Path(__file__).resolve().parent
sys.path.insert(0, str(OPS))

from android_capture_lib import compute_aggregate_status  # noqa: E402


def _screen(*, semantic: bool = True, visual: str = "PENDING") -> dict:
    return {
        "semantic_validation_ok": semantic,
        "visual_review_result": visual,
    }


class AggregateStatusTests(unittest.TestCase):
    def test_fail_when_semantic_missing(self) -> None:
        status, semantic, visual = compute_aggregate_status(
            screens=[_screen(semantic=False)],
            semantic_capture_ok=True,
        )
        self.assertEqual(status, "FAIL")
        self.assertEqual(semantic, "FAIL")
        self.assertEqual(visual, "FAIL")

    def test_pending_when_visual_pending(self) -> None:
        status, semantic, visual = compute_aggregate_status(
            screens=[_screen(visual="PENDING"), _screen(visual="PASS")],
            semantic_capture_ok=True,
        )
        self.assertEqual(status, "PENDING")
        self.assertEqual(semantic, "PASS")
        self.assertEqual(visual, "PENDING")

    def test_fail_when_any_visual_fail(self) -> None:
        status, semantic, visual = compute_aggregate_status(
            screens=[_screen(visual="PASS"), _screen(visual="FAIL")],
            semantic_capture_ok=True,
        )
        self.assertEqual(status, "FAIL")
        self.assertEqual(semantic, "PASS")
        self.assertEqual(visual, "FAIL")

    def test_pass_requires_clean_provenance(self) -> None:
        dirty_tree = {
            "tracked_worktree_clean": False,
            "source_tree_reproducible": False,
            "untracked_source_inputs": ["mobile/android/foo.kt"],
        }
        status, semantic, visual = compute_aggregate_status(
            screens=[_screen(visual="PASS")],
            semantic_capture_ok=True,
            source_tree=dirty_tree,
            rc_source_sha="abc123",
        )
        self.assertEqual(status, "PENDING")
        self.assertEqual(semantic, "PASS")
        self.assertEqual(visual, "PASS")

    def test_pass_when_all_green(self) -> None:
        clean_tree = {
            "tracked_worktree_clean": True,
            "source_tree_reproducible": True,
            "untracked_source_inputs": [],
        }
        status, semantic, visual = compute_aggregate_status(
            screens=[_screen(visual="PASS"), _screen(visual="PASS")],
            semantic_capture_ok=True,
            source_tree=clean_tree,
            rc_source_sha="deadbeef",
            environment_ok=True,
        )
        self.assertEqual(status, "PASS")
        self.assertEqual(semantic, "PASS")
        self.assertEqual(visual, "PASS")


if __name__ == "__main__":
    raise SystemExit(unittest.main())
