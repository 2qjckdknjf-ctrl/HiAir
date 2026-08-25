"""Tests for deploy git SHA resolution."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "release" / "resolve_deploy_git_sha.py"


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )


def test_resolved_release_sha_is_authoritative() -> None:
    sha = "a" * 40
    result = _run(
        "--resolved-release-sha",
        sha,
        "--deploy-git-sha",
        sha,
        "--github-sha",
        sha,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == sha


def test_github_sha_cannot_override_resolved_release_sha() -> None:
    resolved = "a" * 40
    github = "b" * 40
    result = _run("--resolved-release-sha", resolved, "--github-sha", github)
    assert result.returncode != 0


def test_github_sha_must_match_deploy_git_sha_when_both_set() -> None:
    deploy = "c" * 40
    github = "d" * 40
    result = _run("--deploy-git-sha", deploy, "--github-sha", github)
    assert result.returncode != 0


def test_manual_deploy_ancestor_sha_without_github_override() -> None:
    sha = "e" * 40
    result = _run("--deploy-git-sha", sha)
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == sha
