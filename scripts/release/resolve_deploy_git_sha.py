#!/usr/bin/env python3
"""Resolve the single authoritative DEPLOY_GIT_SHA for Cloudflare deploy."""

from __future__ import annotations

import argparse
import sys


def resolve_deploy_git_sha(
    *,
    resolved_release_sha: str = "",
    deploy_git_sha: str = "",
    github_sha: str = "",
) -> str:
    resolved = resolved_release_sha.strip()
    deploy = deploy_git_sha.strip()
    github = github_sha.strip()

    if resolved:
        if deploy and deploy != resolved:
            raise ValueError("DEPLOY_GIT_SHA must match RESOLVED_RELEASE_SHA.")
        if github and github != resolved:
            raise ValueError("GITHUB_SHA must not override RESOLVED_RELEASE_SHA.")
        return resolved

    if deploy:
        if github and github != deploy:
            raise ValueError("GITHUB_SHA must match DEPLOY_GIT_SHA when both are set.")
        return deploy

    return github


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--resolved-release-sha", default="")
    parser.add_argument("--deploy-git-sha", default="")
    parser.add_argument("--github-sha", default="")
    args = parser.parse_args(argv)
    try:
        sha = resolve_deploy_git_sha(
            resolved_release_sha=args.resolved_release_sha,
            deploy_git_sha=args.deploy_git_sha,
            github_sha=args.github_sha,
        )
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    if not sha:
        print("ERROR: DEPLOY_GIT_SHA could not be resolved.", file=sys.stderr)
        return 1
    print(sha)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
