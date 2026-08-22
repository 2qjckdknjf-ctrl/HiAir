#!/usr/bin/env python3
"""Validate production deploy SHA policy for backend-deploy-production workflow."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys

FULL_SHA_RE = re.compile(r"^[0-9a-f]{40}$")


def resolve_release_sha(*, event_name: str, github_ref: str, github_sha: str, input_sha: str) -> str:
    candidate = (input_sha or github_sha or "").strip().lower()
    if not FULL_SHA_RE.fullmatch(candidate):
        raise ValueError(f"Invalid release SHA: {candidate!r}")

    if event_name == "push":
        if github_ref != "refs/heads/main":
            raise ValueError("Push production deploy is only allowed from main.")
        if candidate != github_sha.lower():
            raise ValueError("Push deploy SHA must equal GITHUB_SHA.")
        return candidate

    if event_name != "workflow_dispatch":
        raise ValueError(f"Unsupported event: {event_name}")

    if github_ref != "refs/heads/main":
        raise ValueError("Manual production deploy must be started from main ref.")

    ancestor_check = subprocess.run(
        ["git", "merge-base", "--is-ancestor", candidate, "origin/main"],
        capture_output=True,
        text=True,
    )
    if ancestor_check.returncode != 0:
        raise ValueError("Manual deploy SHA must be reachable from origin/main.")

    return candidate


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--event-name", required=True)
    parser.add_argument("--github-ref", required=True)
    parser.add_argument("--github-sha", required=True)
    parser.add_argument("--input-sha", default="")
    args = parser.parse_args()

    try:
        resolved = resolve_release_sha(
            event_name=args.event_name,
            github_ref=args.github_ref,
            github_sha=args.github_sha,
            input_sha=args.input_sha,
        )
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(resolved)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
