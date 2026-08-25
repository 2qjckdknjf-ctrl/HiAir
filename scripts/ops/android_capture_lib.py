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


def parse_app_window_frame(window_dump: str, package: str = EXPECTED_PACKAGE) -> tuple[int, int, int, int] | None:
    """Parse focused/resumed app window frame from `dumpsys window` output."""
    if not window_dump.strip():
        return None
    blocks = re.split(r"\n(?=Window\{)", window_dump)
    candidates: list[tuple[int, tuple[int, int, int, int]]] = []
    for block in blocks:
        if package not in block:
            continue
        priority = 0
        if re.search(r"mCurrentFocus|mFocusedApp|topResumedActivity", block):
            priority += 4
        if re.search(r"mAttrs=.*TYPE_APPLICATION", block):
            priority += 2
        if re.search(r"isOnScreen=true|mViewVisibility=0", block):
            priority += 1
        frame = None
        for pattern in (
            r"mFrame=\[(\d+),(\d+)\]\[(\d+),(\d+)\]",
            r"frame=\[(\d+),(\d+)\]\[(\d+),(\d+)\]",
            r"mBounds=Rect\((\d+), (\d+) - (\d+), (\d+)\)",
        ):
            match = re.search(pattern, block)
            if match:
                x1, y1, x2, y2 = map(int, match.groups())
                frame = (x1, y1, x2, y2)
                break
        if frame is not None:
            candidates.append((priority, frame))
    if not candidates:
        return None
    candidates.sort(key=lambda item: (item[0], (item[1][2] - item[1][0]) * (item[1][3] - item[1][1])), reverse=True)
    return candidates[0][1]


# Canonical PNG references for targeted visual review (repo-relative paths).
ANDROID_VISUAL_CANONICAL_REFERENCES: dict[str, str | None] = {
    "medium-settings": None,
    "tablet-portrait-paywall": None,
    "tablet-landscape-paywall": None,
    "tablet-portrait-onboarding": "docs/design/redesign-v4/references/04-onboarding-deep-glass.png",
    "tablet-landscape-onboarding": "docs/design/redesign-v4/references/04-onboarding-deep-glass.png",
    "expanded-navigation": None,
    "medium-dashboard": "docs/design/redesign-v4/references/01-home-deep-glass.png",
    "tablet-landscape-dashboard": "docs/design/redesign-v4/references/01-home-deep-glass.png",
    "phone-planner": "docs/design/redesign-v4/references/02-planner-deep-glass.png",
    "tablet-landscape-planner": "docs/design/redesign-v4/references/02-planner-deep-glass.png",
    "phone-symptoms": "docs/design/redesign-v4/references/03-health-deep-glass.png",
    "tablet-landscape-symptoms": "docs/design/redesign-v4/references/03-health-deep-glass.png",
}


def validate_canonical_references(repo_root: Path) -> list[str]:
    """Return missing canonical reference paths (empty list = all present)."""
    missing: list[str] = []
    for shot_id, ref in ANDROID_VISUAL_CANONICAL_REFERENCES.items():
        if ref is None:
            continue
        path = repo_root / ref
        if not path.is_file():
            missing.append(f"{shot_id}: {ref}")
    return missing


def visual_review_is_complete(review: dict[str, Any]) -> bool:
    gate = str(review.get("visual_gate", "")).upper()
    if "PASS" in gate and "PENDING" not in gate:
        return True
    shots = review.get("shots") or []
    if not shots:
        return False
    results = [str(shot.get("visual_result", "PENDING")).upper() for shot in shots]
    return bool(results) and all(result == "PASS" for result in results)


def sync_visual_review_to_manifest(manifest: dict[str, Any], review: dict[str, Any]) -> dict[str, Any]:
    """Merge completed visual-review.json results into targeted-visual manifest.json."""
    review_by_id = {str(shot.get("id")): shot for shot in review.get("shots", []) if shot.get("id")}
    primary_ids = set(ANDROID_VISUAL_CANONICAL_REFERENCES.keys())
    for shot in manifest.get("shots", []):
        shot_id = str(shot.get("id", ""))
        if shot_id in review_by_id:
            shot["visual_review"] = review_by_id[shot_id].get("visual_result", "PENDING")
        elif shot_id.endswith("-end-scroll"):
            shot["visual_review"] = "SUPPLEMENTAL"
        elif shot_id not in primary_ids:
            shot["visual_review"] = shot.get("visual_review", "PENDING")
    manifest["visual_review"] = review.get("visual_gate", manifest.get("visual_review", "PENDING"))
    manifest["visual_review_path"] = "visual-review.json"
    if review.get("shelf_gate"):
        manifest["shelf_gate"] = review["shelf_gate"]
    if review.get("reviewed_at"):
        manifest["visual_reviewed_at"] = review["reviewed_at"]
    return manifest


def build_visual_review_template(
    *,
    evidence_dir: str,
    manifest_path: str,
    prior_review: str | None = None,
) -> dict[str, Any]:
    shots = []
    for shot_id, canonical in ANDROID_VISUAL_CANONICAL_REFERENCES.items():
        shots.append(
            {
                "id": shot_id,
                "semantic_result": "PASS",
                "visual_result": "PENDING",
                "screenshot": f"{shot_id}.app.png",
                "canonical_reference": canonical,
                "crop_cleanliness": "PENDING",
                "safe_area_correctness": "PENDING",
                "responsive_composition": "PENDING",
                "information_completeness": "PENDING",
                "v4_hierarchy": "PENDING",
                "nav_clearance": "PENDING",
                "deviations": [],
                "required_fixes": [],
                "reviewed_at": None,
            },
        )
    return {
        "overall": "SEMANTIC PASS / VISUAL PENDING / NOT RC EVIDENCE",
        "semantic_gate": "PENDING",
        "visual_gate": "PENDING MANUAL REVIEW",
        "capture_manifest": manifest_path,
        "prior_review": prior_review,
        "reviewed_at": None,
        "notes": "Review only *.app.png. Phone = V4 hierarchy; tablet = responsive composition; Settings/Paywall = component system.",
        "shots": shots,
    }


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
