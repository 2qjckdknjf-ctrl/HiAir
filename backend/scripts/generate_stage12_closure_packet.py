import argparse
import json
from datetime import UTC, datetime
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_EVIDENCE_JSON = REPO_ROOT / "docs" / "_operator" / "stage12-evidence-latest.json"
DEFAULT_OUTPUT_MD = REPO_ROOT / "docs" / "_operator" / "stage12-closure-packet.md"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Stage 12 closure packet markdown from evidence JSON.")
    parser.add_argument(
        "--evidence-json",
        default=str(DEFAULT_EVIDENCE_JSON),
        help="Path to stage12 evidence JSON file.",
    )
    parser.add_argument(
        "--output",
        default=str(DEFAULT_OUTPUT_MD),
        help="Path to output markdown packet.",
    )
    args = parser.parse_args()

    evidence_path = Path(args.evidence_json).expanduser()
    output_path = Path(args.output).expanduser()

    if not evidence_path.exists():
        raise SystemExit(f"Evidence file not found: {evidence_path}")

    payload = json.loads(evidence_path.read_text(encoding="utf-8"))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(_render(payload), encoding="utf-8")
    print(f"Wrote Stage 12 closure packet: {output_path}")
    return 0


def _render(payload: dict) -> str:
    collected_at = payload.get("collected_at_utc", "unknown")
    git_head = payload.get("git_head", "unknown")
    overall_status = payload.get("overall_status", "unknown")
    counts = payload.get("counts", {})
    items = payload.get("items", [])

    lines: list[str] = []
    lines.append("# Stage 12 Closure Packet")
    lines.append("")
    lines.append(f"Generated at (UTC): {datetime.now(tz=UTC).isoformat()}")
    lines.append(f"Evidence collected at (UTC): {collected_at}")
    lines.append(f"Git HEAD: `{git_head}`")
    lines.append("")
    lines.append("## Automated Verification Summary")
    lines.append("")
    lines.append(f"- Overall status: **{overall_status}**")
    lines.append(f"- Done: `{counts.get('done', 0)}`")
    lines.append(f"- Blocked: `{counts.get('blocked', 0)}`")
    lines.append(f"- Failed: `{counts.get('failed', 0)}`")
    lines.append(f"- Total checks: `{counts.get('total', 0)}`")
    lines.append("")
    lines.append("| Check | Status | Exit Code |")
    lines.append("|---|---|---:|")
    for item in items:
        lines.append(
            f"| `{item.get('name', '-')}` | `{item.get('status', '-')}` | `{item.get('exit_code', '-')}` |"
        )
    lines.append("")
    lines.append("## Evidence Source")
    lines.append("")
    lines.append("- Machine-readable evidence JSON:")
    lines.append(f"  - `{_relative_path(DEFAULT_EVIDENCE_JSON)}`")
    lines.append("")
    lines.append("## Remaining Manual Artifacts")
    lines.append("")
    lines.append("- [ ] Device QA packet attached (fill report path)")
    lines.append("  - Suggested artifact: `docs/qa-run-007-report.md`")
    lines.append("- [ ] Demo video attached (fill link/path)")
    lines.append("  - Suggested artifact: `docs/_operator/stage12-demo-video-link.md`")
    lines.append("")
    lines.append("## Reviewer Notes")
    lines.append("")
    lines.append("- This packet is generated automatically from the latest Stage 12 evidence JSON.")
    lines.append("- Manual artifacts remain explicit checkboxes to prevent false closure.")
    lines.append("")
    return "\n".join(lines)


def _relative_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(REPO_ROOT.resolve()))
    except ValueError:
        return str(path)


if __name__ == "__main__":
    raise SystemExit(main())
