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


def normalize_sha(sha: str | None) -> str | None:
    if sha is None:
        return None
    trimmed = str(sha).strip()
    return trimmed if trimmed else None


def provenance_ready(
    *,
    source_tree: dict[str, Any] | None,
    source_sha: str | None,
    rc_source_sha: str | None,
) -> tuple[bool, list[str]]:
    blockers: list[str] = []
    normalized_rc = normalize_sha(rc_source_sha)
    normalized_source = normalize_sha(source_sha)

    if normalized_rc is None:
        blockers.append("rc_source_sha missing")
        return False, blockers

    if source_tree is None:
        blockers.append("source_tree missing")
        return False, blockers

    if not source_tree.get("tracked_worktree_clean"):
        blockers.append("tracked_worktree_clean=false")
    if not source_tree.get("source_tree_reproducible", source_tree.get("tracked_worktree_clean")):
        blockers.append("source_tree_reproducible=false")
    if source_tree.get("untracked_source_inputs"):
        blockers.append("untracked_source_inputs present")

    if normalized_source and normalized_rc != normalized_source:
        blockers.append(f"rc_source_sha mismatch source_sha={normalized_source} rc_source_sha={normalized_rc}")

    return len(blockers) == 0, blockers


def compute_aggregate_status(
    *,
    screens: list[dict[str, Any]],
    capture_completed: bool,
    semantic_capture_ok: bool,
    source_tree: dict[str, Any] | None = None,
    source_sha: str | None = None,
    rc_source_sha: str | None = None,
    environment_ok: bool = True,
    environment_errors: list[str] | None = None,
) -> tuple[str, str, str, list[str]]:
    """Return (aggregate_status, semantic_validation, visual_review_result, blockers)."""
    blockers: list[str] = []

    if not screens:
        return "FAIL", "FAIL", "FAIL", ["no screens captured"]

    per_screen_semantic_ok = all(s.get("semantic_validation_ok") for s in screens)
    if not capture_completed:
        blockers.append("capture incomplete")
        return "FAIL", "FAIL" if not per_screen_semantic_ok else "PASS", "FAIL", blockers

    if not semantic_capture_ok or not per_screen_semantic_ok:
        return "FAIL", "FAIL", "FAIL", blockers + ["semantic validation failed"]

    visual_results = [str(s.get("visual_review_result", "PENDING")).upper() for s in screens]
    if any(result == "FAIL" for result in visual_results):
        return "FAIL", "PASS", "FAIL", blockers

    if any(result == "PENDING" for result in visual_results):
        return "PENDING", "PASS", "PENDING", blockers

    if not all(result == "PASS" for result in visual_results):
        return "FAIL", "PASS", "FAIL", blockers

    if environment_errors:
        blockers.extend(environment_errors)
    if not environment_ok:
        blockers.append("environment mismatch")
        return "PENDING", "PASS", "PASS", blockers

    prov_ok, prov_blockers = provenance_ready(
        source_tree=source_tree,
        source_sha=source_sha,
        rc_source_sha=rc_source_sha,
    )
    if not prov_ok:
        blockers.extend(prov_blockers)
        return "PENDING", "PASS", "PASS", blockers

    return "PASS", "PASS", "PASS", blockers


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
    capture_completed: bool = True,
    semantic_capture_ok: bool | None = None,
    failure_reason: str | None = None,
    rc_source_sha: str | None = None,
    environment_ok: bool = True,
    environment_errors: list[str] | None = None,
) -> dict[str, Any]:
    if semantic_capture_ok is None:
        semantic_capture_ok = capture_completed and bool(screens) and all(
            s.get("semantic_validation_ok") for s in screens
        )

    resolved_rc_sha = normalize_sha(rc_source_sha)
    if resolved_rc_sha is None and source_tree.get("tracked_worktree_clean"):
        resolved_rc_sha = normalize_sha(source_sha)

    overall, semantic_label, visual_label, blockers = compute_aggregate_status(
        screens=screens,
        capture_completed=capture_completed,
        semantic_capture_ok=semantic_capture_ok,
        source_tree=source_tree,
        source_sha=source_sha,
        rc_source_sha=resolved_rc_sha,
        environment_ok=environment_ok,
        environment_errors=environment_errors,
    )
    return {
        "captured_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "artifact_kind": "android_store_screenshot_evidence",
        "status": overall,
        "aggregate_status": overall,
        "failure_reason": failure_reason,
        "aggregate_blockers": blockers,
        "provenance": source_tree,
        "source_sha": source_sha,
        "rc_source_sha": resolved_rc_sha,
        "run_id": run_id,
        "test_configuration": test_configuration,
        "requested_environment": requested,
        "app_observed_environment": observed,
        "output_dir": str(out_dir),
        "screens": screens,
        "semantic_validation": semantic_label,
        "visual_review_result": visual_label,
        "capture_completed": capture_completed,
        "semantic_capture_ok": semantic_capture_ok,
    }


def write_manifest(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
