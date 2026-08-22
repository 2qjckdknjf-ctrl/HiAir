"""Policy tests for production deploy SHA resolution."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "release" / "resolve_production_deploy_sha.py"


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )


def test_push_from_main_uses_github_sha() -> None:
    sha = "a" * 40
    result = _run(
        "--event-name",
        "push",
        "--github-ref",
        "refs/heads/main",
        "--github-sha",
        sha,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == sha


def test_push_from_non_main_is_rejected() -> None:
    result = _run(
        "--event-name",
        "push",
        "--github-ref",
        "refs/heads/cursor/foo",
        "--github-sha",
        "a" * 40,
    )
    assert result.returncode != 0


def test_dispatch_requires_main_ref() -> None:
    result = _run(
        "--event-name",
        "workflow_dispatch",
        "--github-ref",
        "refs/heads/cursor/store-ready-hardening-2026-08-22",
        "--github-sha",
        "b" * 40,
        "--input-sha",
        "a" * 40,
    )
    assert result.returncode != 0
