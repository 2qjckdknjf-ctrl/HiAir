#!/usr/bin/env python3
"""Shared helpers for Android capture manifests and environment checks."""

from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

EXPECTED_PACKAGE = "com.hiair"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def parse_foreground_package(dumpsys_text: str) -> str | None:
    patterns = (
        r"mResumedActivity:.*? ([a-zA-Z0-9_.]+)/",
        r"topResumedActivity=ActivityRecord\{.*? ([a-zA-Z0-9_.]+)/",
        r"mFocusedApp=ActivityRecord\{.*? ([a-zA-Z0-9_.]+)/",
        r"mCurrentFocus=Window\{.*? ([a-zA-Z0-9_.]+)/",
        r"focusedApp=.*?ActivityRecord\{.*? ([a-zA-Z0-9_.]+)/",
        r"^\s*package=([a-zA-Z0-9_.]+)\s",
    )
    for pattern in patterns:
        match = re.search(pattern, dumpsys_text, re.MULTILINE)
        if match:
            return match.group(1)
    return None


def foreground_package_from_adb_output(activity_dump: str, window_dump: str = "") -> str | None:
    return parse_foreground_package(activity_dump) or parse_foreground_package(window_dump)


def compare_observed_environment(requested: dict[str, Any], observed: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if requested.get("captureRunId") != observed.get("captureRunId"):
        errors.append(
            f"captureRunId mismatch requested={requested.get('captureRunId')} observed={observed.get('captureRunId')}",
        )
    req_lang = str(requested.get("language", "")).lower()[:2]
    obs_locale = str(observed.get("locale", "")).lower()
    if req_lang and not obs_locale.startswith(req_lang):
        errors.append(f"locale mismatch requested={requested.get('language')} observed={observed.get('locale')}")
    req_scale = float(requested.get("fontScale", 1.0))
    obs_scale = float(observed.get("fontScale", 0.0))
    if abs(req_scale - obs_scale) > 0.01:
        errors.append(f"fontScale mismatch requested={req_scale} observed={obs_scale}")
    if bool(requested.get("reduceMotion")) != bool(observed.get("reduceMotion")):
        errors.append(
            f"reduceMotion mismatch requested={requested.get('reduceMotion')} observed={observed.get('reduceMotion')}",
        )
    if requested.get("avdName") and observed.get("avdName") and requested.get("avdName") != observed.get("avdName"):
        errors.append(f"avdName mismatch requested={requested.get('avdName')} observed={observed.get('avdName')}")
    if requested.get("serial") and observed.get("serial") and requested.get("serial") != observed.get("serial"):
        errors.append(f"serial mismatch requested={requested.get('serial')} observed={observed.get('serial')}")
    return errors


def compute_aggregate_status(
    *,
    screens: list[dict[str, Any]],
    semantic_capture_ok: bool,
    source_tree: dict[str, Any] | None = None,
    rc_source_sha: str | None = None,
    environment_ok: bool = True,
) -> tuple[str, str, str]:
    """Return (overall_status, semantic_validation, visual_review_result)."""
    if not screens:
        return "FAIL", "FAIL", "FAIL"

    semantic_ok = all(s.get("semantic_validation_ok") for s in screens)
    if not semantic_ok or not semantic_capture_ok:
        return "FAIL", "FAIL", "FAIL"

    visual_results = [str(s.get("visual_review_result", "PENDING")).upper() for s in screens]
    if any(result == "FAIL" for result in visual_results):
        return "FAIL", "PASS", "FAIL"
    if any(result == "PENDING" for result in visual_results):
        return "PENDING", "PASS", "PENDING"

    visual_ok = all(result == "PASS" for result in visual_results)
    if not visual_ok:
        return "FAIL", "PASS", "FAIL"

    provenance_ok = True
    if source_tree is not None:
        provenance_ok = (
            bool(source_tree.get("tracked_worktree_clean"))
            and bool(source_tree.get("source_tree_reproducible", source_tree.get("tracked_worktree_clean")))
            and not source_tree.get("untracked_source_inputs")
        )
    if rc_source_sha is not None and not rc_source_sha.strip():
        provenance_ok = False

    if not environment_ok or not provenance_ok:
        return "PENDING", "PASS", "PASS"

    return "PASS", "PASS", "PASS"


def build_manifest(
    *,
    out_dir: Path,
    source_tree: dict[str, Any],
    source_sha: str,
    run_id: str,
    requested: dict[str, Any],
    observed: dict[str, Any],
    screens: list[dict[str, Any]],
    test_configuration: dict[str, Any],
    status: str,
    failure_reason: str | None = None,
    rc_source_sha: str | None = None,
    environment_ok: bool = True,
) -> dict[str, Any]:
    semantic_capture_ok = status == "PASS"
    overall, semantic_label, visual_label = compute_aggregate_status(
        screens=screens,
        semantic_capture_ok=semantic_capture_ok,
        source_tree=source_tree,
        rc_source_sha=rc_source_sha,
        environment_ok=environment_ok,
    )
    return {
        "captured_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "artifact_kind": "android_store_screenshot_evidence",
        "status": overall,
        "failure_reason": failure_reason,
        "provenance": source_tree,
        "source_sha": source_sha,
        "rc_source_sha": rc_source_sha,
        "run_id": run_id,
        "test_configuration": test_configuration,
        "requested_environment": requested,
        "app_observed_environment": observed,
        "output_dir": str(out_dir),
        "screens": screens,
        "semantic_validation": semantic_label,
        "visual_review_result": visual_label,
    }


def write_manifest(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
