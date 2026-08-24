#!/usr/bin/env python3
"""Unit tests for Android screenshot semantic validator."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

OPS = Path(__file__).resolve().parent
sys.path.insert(0, str(OPS))

from android_capture_validate import validate_hierarchy  # noqa: E402


def _xml(*nodes: str) -> str:
    body = "".join(nodes)
    return f'<?xml version="1.0" encoding="UTF-8"?><hierarchy>{body}</hierarchy>'


class ValidateHierarchyTests(unittest.TestCase):
    def test_pass_with_marker_and_hiair_foreground(self) -> None:
        xml = _xml('<node content-desc="screen.dashboard.root" text="Dashboard" />')
        result = validate_hierarchy(xml, expected_marker="screen.dashboard.root", foreground_package="com.hiair")
        self.assertTrue(result.ok, result.errors)

    def test_fail_missing_marker(self) -> None:
        xml = _xml('<node content-desc="other" text="Dashboard" />')
        result = validate_hierarchy(xml, expected_marker="screen.dashboard.root", foreground_package="com.hiair")
        self.assertFalse(result.ok)
        self.assertTrue(any("missing screen marker" in e for e in result.errors))

    def test_fail_wrong_foreground_package(self) -> None:
        xml = _xml('<node content-desc="screen.dashboard.root" />')
        result = validate_hierarchy(
            xml,
            expected_marker="screen.dashboard.root",
            foreground_package="com.android.launcher3",
        )
        self.assertFalse(result.ok)
        self.assertTrue(any("foreground package expected" in e for e in result.errors))

    def test_fail_launcher_in_hierarchy(self) -> None:
        xml = _xml(
            '<node package="com.google.android.apps.nexuslauncher" content-desc="Home" />',
        )
        result = validate_hierarchy(xml, expected_marker="screen.dashboard.root", foreground_package="com.hiair")
        self.assertFalse(result.ok)
        self.assertTrue(any("launcher UI" in e for e in result.errors))

    def test_fail_crash_dialog(self) -> None:
        xml = _xml('<node text="HiAir has stopped" />')
        result = validate_hierarchy(xml, expected_marker="screen.dashboard.root", foreground_package="com.hiair")
        self.assertFalse(result.ok)
        self.assertTrue(any("crash dialog" in e for e in result.errors))

    def test_fail_raw_localization_key(self) -> None:
        xml = _xml('<node content-desc="screen.dashboard.root" text="planner.fetch" />')
        result = validate_hierarchy(xml, expected_marker="screen.dashboard.root", foreground_package="com.hiair")
        self.assertFalse(result.ok)
        self.assertTrue(any("raw localization key" in e for e in result.errors))

    def test_fail_success_state_connection_error(self) -> None:
        xml = _xml(
            '<node content-desc="screen.insights.root" text="Unable to connect" />',
        )
        result = validate_hierarchy(xml, expected_marker="screen.insights.root", foreground_package="com.hiair")
        self.assertFalse(result.ok)
        self.assertTrue(any("error/loading UI" in e for e in result.errors))


class CliTests(unittest.TestCase):
    CLI = OPS / "android_capture_validate_cli.py"

    def _run(self, *extra: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(self.CLI), *extra],
            capture_output=True,
            text=True,
        )

    def test_cli_pass(self) -> None:
        with tempfile.NamedTemporaryFile("w", suffix=".xml", delete=False) as handle:
            handle.write(_xml('<node content-desc="screen.dashboard.root" />'))
            path = handle.name
        proc = self._run(path, "screen.dashboard.root", "com.hiair")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("OK", proc.stdout)

    def test_cli_usage_on_missing_args(self) -> None:
        proc = self._run("only-one-arg")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("usage", proc.stderr.lower())


if __name__ == "__main__":
    raise SystemExit(unittest.main())
