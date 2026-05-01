import argparse
import json
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CLOSURE_PACKET = REPO_ROOT / "docs" / "_operator" / "stage12-closure-packet.md"
DEFAULT_QA_REPORT = REPO_ROOT / "docs" / "qa-run-007-report.md"
DEFAULT_DEMO_LINK = REPO_ROOT / "docs" / "_operator" / "stage12-demo-video-link.md"
DEFAULT_EVIDENCE_JSON = REPO_ROOT / "docs" / "_operator" / "stage12-evidence-latest.json"


def main() -> int:
    parser = argparse.ArgumentParser(description="Check whether Stage 12 closure packet is fully ready.")
    parser.add_argument("--json-output", default=None, help="Optional path to write machine-readable readiness JSON.")
    args = parser.parse_args()

    checks = [
        _exists_check("closure_packet_exists", DEFAULT_CLOSURE_PACKET),
        _exists_check("qa_report_exists", DEFAULT_QA_REPORT),
        _exists_check("demo_link_file_exists", DEFAULT_DEMO_LINK),
        _exists_check("evidence_json_exists", DEFAULT_EVIDENCE_JSON),
        _evidence_status_check(),
        _closure_checkbox_check(),
        _demo_link_filled_check(),
    ]

    all_ready = all(item["status"] == "READY" for item in checks)
    report = {
        "stage": "stage12-closure",
        "all_ready": all_ready,
        "checks": checks,
    }

    for item in checks:
        print(f"[{item['status']}] {item['name']}: {item['detail']}")
    print("Stage 12 closure readiness:", "READY" if all_ready else "NOT_READY")

    if args.json_output:
        path = Path(args.json_output).expanduser()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(report, ensure_ascii=True, indent=2), encoding="utf-8")
        print(f"Wrote readiness JSON: {path}")

    return 0 if all_ready else 1


def _exists_check(name: str, path: Path) -> dict[str, str]:
    exists = path.exists()
    return {
        "name": name,
        "status": "READY" if exists else "NOT_READY",
        "detail": f"{path} {'exists' if exists else 'is missing'}",
    }


def _evidence_status_check() -> dict[str, str]:
    if not DEFAULT_EVIDENCE_JSON.exists():
        return {
            "name": "evidence_json_overall_status",
            "status": "NOT_READY",
            "detail": f"{DEFAULT_EVIDENCE_JSON} is missing",
        }
    payload = json.loads(DEFAULT_EVIDENCE_JSON.read_text(encoding="utf-8"))
    status = payload.get("overall_status")
    return {
        "name": "evidence_json_overall_status",
        "status": "READY" if status == "DONE" else "NOT_READY",
        "detail": f"overall_status={status}",
    }


def _closure_checkbox_check() -> dict[str, str]:
    if not DEFAULT_CLOSURE_PACKET.exists():
        return {
            "name": "closure_packet_manual_checkboxes",
            "status": "NOT_READY",
            "detail": f"{DEFAULT_CLOSURE_PACKET} is missing",
        }
    content = DEFAULT_CLOSURE_PACKET.read_text(encoding="utf-8")
    device_checked = re.search(r"- \[x\] Device QA packet attached", content) is not None
    demo_checked = re.search(r"- \[x\] Demo video attached", content) is not None
    ready = device_checked and demo_checked
    return {
        "name": "closure_packet_manual_checkboxes",
        "status": "READY" if ready else "NOT_READY",
        "detail": f"device_checked={device_checked}, demo_checked={demo_checked}",
    }


def _demo_link_filled_check() -> dict[str, str]:
    if not DEFAULT_DEMO_LINK.exists():
        return {
            "name": "demo_video_link_content",
            "status": "NOT_READY",
            "detail": f"{DEFAULT_DEMO_LINK} is missing",
        }
    content = DEFAULT_DEMO_LINK.read_text(encoding="utf-8")
    pending_markers = [
        "pending manual recording",
        "replace this file content",
    ]
    has_pending_marker = any(marker in content.lower() for marker in pending_markers)
    has_url = bool(re.search(r"https?://", content))
    artifact_match = re.search(r"`(docs/_operator/[^`]+\.mp4)`", content)
    has_existing_artifact = False
    if artifact_match:
        artifact_path = (REPO_ROOT / artifact_match.group(1)).resolve()
        has_existing_artifact = artifact_path.exists()
    ready = (has_url or has_existing_artifact) and not has_pending_marker
    return {
        "name": "demo_video_link_content",
        "status": "READY" if ready else "NOT_READY",
        "detail": f"has_url={has_url}, has_existing_artifact={has_existing_artifact}, has_pending_marker={has_pending_marker}",
    }


if __name__ == "__main__":
    raise SystemExit(main())
