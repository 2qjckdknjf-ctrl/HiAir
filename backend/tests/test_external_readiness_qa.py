"""Fail-closed regression tests for real-device QA release evidence."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


def _load_checker():
    root = Path(__file__).resolve().parents[2]
    path = root / "scripts" / "release" / "check_external_readiness.py"
    spec = importlib.util.spec_from_file_location("check_external_readiness", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def test_historical_pass_rows_do_not_close_current_blocked_certification(tmp_path: Path) -> None:
    report = tmp_path / "qa.md"
    report.write_text(
        """
# Real Device QA Report

## Current release certification
Status: BLOCKED

| Critical flow | Result |
|---|---|
| install/open app | BLOCKED |

## Historical preflight

| Check | Result |
|---|---|
| Backend smoke | PASS |
| Release build | PASS |
""",
        encoding="utf-8",
    )

    result = _load_checker().check_qa_execution(report)

    assert result.status == "BLOCKED"
    assert "Status: BLOCKED" in result.detail


def test_current_pass_section_closes_only_when_all_rows_pass(tmp_path: Path) -> None:
    report = tmp_path / "qa.md"
    report.write_text(
        """
# Real Device QA Report

## Current release certification
Status: PASS

| Critical flow | Result |
|---|---|
| install/open app | PASS |
| logout | PASS |

## Historical blocked run

| Check | Result |
|---|---|
| Old device run | BLOCKED |
""",
        encoding="utf-8",
    )

    result = _load_checker().check_qa_execution(report)

    assert result.status == "DONE"
    assert "2 PASS rows" in result.detail


def test_status_pass_with_unresolved_current_row_fails_closed(tmp_path: Path) -> None:
    report = tmp_path / "qa.md"
    report.write_text(
        """
# Real Device QA Report

## Current release certification
Status: PASS

| Critical flow | Result |
|---|---|
| install/open app | PASS |
| StoreKit sandbox | NOT RUN |
""",
        encoding="utf-8",
    )

    result = _load_checker().check_qa_execution(report)

    assert result.status == "BLOCKED"
    assert "1 unresolved rows" in result.detail


def test_pass_rows_without_current_certification_section_fail_closed(tmp_path: Path) -> None:
    report = tmp_path / "qa.md"
    report.write_text(
        """
# Real Device QA Report

## Historical preflight

| Check | Result |
|---|---|
| Backend smoke | PASS |
""",
        encoding="utf-8",
    )

    result = _load_checker().check_qa_execution(report)

    assert result.status == "BLOCKED"
    assert "Current release certification" in result.detail
