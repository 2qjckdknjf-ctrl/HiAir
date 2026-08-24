#!/usr/bin/env python3
"""Unit tests for Android capture manifest aggregate status."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

OPS = Path(__file__).resolve().parent
sys.path.insert(0, str(OPS))

from android_capture_lib import compute_aggregate_status, provenance_ready  # noqa: E402


def _screen(*, semantic: bool = True, visual: str = "PENDING") -> dict:
    return {
        "semantic_validation_ok": semantic,
        "visual_review_result": visual,
    }


CLEAN_TREE = {
    "tracked_worktree_clean": True,
    "source_tree_reproducible": True,
    "untracked_source_inputs": [],
}


class AggregateStatusTests(unittest.TestCase):
    def test_fail_when_semantic_missing(self) -> None:
        status, semantic, visual, _ = compute_aggregate_status(
            screens=[_screen(semantic=False)],
            capture_completed=True,
            semantic_capture_ok=False,
        )
        self.assertEqual(status, "FAIL")
        self.assertEqual(semantic, "FAIL")
        self.assertEqual(visual, "FAIL")

    def test_pending_when_visual_pending(self) -> None:
        status, semantic, visual, _ = compute_aggregate_status(
            screens=[_screen(visual="PENDING"), _screen(visual="PASS")],
            capture_completed=True,
            semantic_capture_ok=True,
        )
        self.assertEqual(status, "PENDING")
        self.assertEqual(semantic, "PASS")
        self.assertEqual(visual, "PENDING")

    def test_fail_when_any_visual_fail(self) -> None:
        status, semantic, visual, _ = compute_aggregate_status(
            screens=[_screen(visual="PASS"), _screen(visual="FAIL")],
            capture_completed=True,
            semantic_capture_ok=True,
        )
        self.assertEqual(status, "FAIL")
        self.assertEqual(semantic, "PASS")
        self.assertEqual(visual, "FAIL")

    def test_pending_when_rc_source_sha_none(self) -> None:
        status, semantic, visual, blockers = compute_aggregate_status(
            screens=[_screen(visual="PASS")],
            capture_completed=True,
            semantic_capture_ok=True,
            source_tree=CLEAN_TREE,
            source_sha="abc123",
            rc_source_sha=None,
        )
        self.assertEqual(status, "PENDING")
        self.assertEqual(semantic, "PASS")
        self.assertEqual(visual, "PASS")
        self.assertTrue(any("rc_source_sha missing" in b for b in blockers))

    def test_pending_when_rc_source_sha_blank(self) -> None:
        status, _, _, blockers = compute_aggregate_status(
            screens=[_screen(visual="PASS")],
            capture_completed=True,
            semantic_capture_ok=True,
            source_tree=CLEAN_TREE,
            source_sha="abc123",
            rc_source_sha="   ",
        )
        self.assertEqual(status, "PENDING")
        self.assertTrue(any("rc_source_sha missing" in b for b in blockers))

    def test_pending_when_dirty_tree(self) -> None:
        dirty_tree = {
            "tracked_worktree_clean": False,
            "source_tree_reproducible": False,
            "untracked_source_inputs": ["mobile/android/foo.kt"],
        }
        status, semantic, visual, blockers = compute_aggregate_status(
            screens=[_screen(visual="PASS")],
            capture_completed=True,
            semantic_capture_ok=True,
            source_tree=dirty_tree,
            source_sha="abc123",
            rc_source_sha="abc123",
        )
        self.assertEqual(status, "PENDING")
        self.assertEqual(semantic, "PASS")
        self.assertEqual(visual, "PASS")
        self.assertTrue(blockers)

    def test_pending_when_untracked_source_inputs(self) -> None:
        tree = {
            "tracked_worktree_clean": True,
            "source_tree_reproducible": True,
            "untracked_source_inputs": ["scripts/ops/foo.py"],
        }
        ok, blockers = provenance_ready(source_tree=tree, source_sha="abc", rc_source_sha="abc")
        self.assertFalse(ok)
        self.assertTrue(any("untracked_source_inputs" in b for b in blockers))

    def test_pending_on_environment_mismatch(self) -> None:
        status, _, _, blockers = compute_aggregate_status(
            screens=[_screen(visual="PASS")],
            capture_completed=True,
            semantic_capture_ok=True,
            source_tree=CLEAN_TREE,
            source_sha="deadbeef",
            rc_source_sha="deadbeef",
            environment_ok=False,
            environment_errors=["locale mismatch requested=en observed=ru"],
        )
        self.assertEqual(status, "PENDING")
        self.assertTrue(any("environment mismatch" in b for b in blockers))

    def test_pass_when_all_green(self) -> None:
        status, semantic, visual, blockers = compute_aggregate_status(
            screens=[_screen(visual="PASS"), _screen(visual="PASS")],
            capture_completed=True,
            semantic_capture_ok=True,
            source_tree=CLEAN_TREE,
            source_sha="deadbeef",
            rc_source_sha="deadbeef",
            environment_ok=True,
        )
        self.assertEqual(status, "PASS")
        self.assertEqual(semantic, "PASS")
        self.assertEqual(visual, "PASS")
        self.assertEqual(blockers, [])


if __name__ == "__main__":
    raise SystemExit(unittest.main())
