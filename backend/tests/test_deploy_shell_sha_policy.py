"""Shell integration tests for deploy SHA policy in deploy_hiair_api_cloudflare.sh."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEPLOY_SCRIPT = ROOT / "scripts" / "ops" / "deploy_hiair_api_cloudflare.sh"
RESOLVE_SCRIPT = ROOT / "scripts" / "release" / "resolve_deploy_git_sha.py"


def _extract_deploy_git_sha_from_script_snippet(env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    snippet = f"""
set -euo pipefail
ROOT_DIR="{ROOT}"
RESOLVED_RELEASE_SHA="${{RESOLVED_RELEASE_SHA:-}}"
DEPLOY_GIT_SHA_INPUT="${{DEPLOY_GIT_SHA:-}}"
GITHUB_SHA_INPUT="${{GITHUB_SHA:-}}"
DEPLOY_GIT_SHA="$(
  python3 "{RESOLVE_SCRIPT}" \
    --resolved-release-sha "${{RESOLVED_RELEASE_SHA}}" \
    --deploy-git-sha "${{DEPLOY_GIT_SHA_INPUT}}" \
    --github-sha "${{GITHUB_SHA_INPUT}}"
)" || exit 1
printf '%s' "$DEPLOY_GIT_SHA"
"""
    return subprocess.run(
        ["bash", "-c", snippet],
        cwd=ROOT,
        env={**os.environ, **env},
        capture_output=True,
        text=True,
    )


def test_deploy_script_snippet_uses_resolved_release_sha() -> None:
    sha = "a" * 40
    result = _extract_deploy_git_sha_from_script_snippet(
        {
            "RESOLVED_RELEASE_SHA": sha,
            "DEPLOY_GIT_SHA": sha,
            "GITHUB_SHA": "b" * 40,
        }
    )
    assert result.returncode != 0, result.stdout


def test_deploy_script_snippet_manual_deploy_git_sha() -> None:
    sha = "c" * 40
    result = _extract_deploy_git_sha_from_script_snippet(
        {
            "RESOLVED_RELEASE_SHA": "",
            "DEPLOY_GIT_SHA": sha,
            "GITHUB_SHA": "",
        }
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == sha


def test_deploy_script_exists_and_resolves_sha_before_secrets() -> None:
    text = DEPLOY_SCRIPT.read_text(encoding="utf-8")
    assert "resolve_deploy_git_sha.py" in text
    assert "GITHUB_SHA must not override" not in text
    assert text.index("resolve_deploy_git_sha.py") < text.index("syncing wrangler secrets")
