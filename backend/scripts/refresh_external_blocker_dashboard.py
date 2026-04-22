import json
import re
import subprocess
from datetime import UTC, datetime
from pathlib import Path


REPO = "2qjckdknjf-ctrl/HiAir"
OUTPUT_PATH = Path(__file__).resolve().parents[2] / "docs" / "_operator" / "external-blocker-dashboard.md"
OPERATOR_DIR = OUTPUT_PATH.parent

NEXT_ACTIONS = {
    "EXT-001": "Confirm App Store Connect access and attach evidence in issue thread",
    "EXT-002": "Confirm Play Console access and attach internal track upload evidence",
    "EXT-003": "Confirm legal owner and attach signoff artifact + final policy URLs",
    "EXT-004": "Confirm security/ops owner and attach secrets governance approval",
    "EXT-005": "Attach finalized store metadata packet and compliance evidence",
}


def _run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True).strip()


def _load_blockers() -> list[dict[str, object]]:
    raw = _run(
        [
            "gh",
            "issue",
            "list",
            "--repo",
            REPO,
            "--label",
            "external-blocker",
            "--json",
            "number,title,state,url,assignees,updatedAt,milestone",
            "--limit",
            "50",
        ]
    )
    return json.loads(raw)


def _extract_ext_id(title: str) -> str:
    match = re.match(r"(EXT-\d+):", title)
    return match.group(1) if match else "EXT-UNK"


def _render_markdown(rows: list[dict[str, object]]) -> str:
    ts = datetime.now(tz=UTC).strftime("%Y-%m-%d")
    latest_daily_update = _latest_daily_update_doc()
    lines = [
        "# HiAir External Blocker Dashboard",
        "",
        f"Last updated: {ts}",
        "",
        "Live tracking dashboard for release-blocking non-code dependencies.",
        "",
        "| ID | Issue | Status | Assignee | Target date | Last update (UTC) | Immediate next action |",
        "|---|---|---|---|---|---|---|",
    ]

    ext_rows = [row for row in rows if _extract_ext_id(str(row["title"])) != "EXT-UNK"]
    sorted_rows = sorted(ext_rows, key=lambda item: int(item["number"]))
    for row in sorted_rows:
        ext_id = _extract_ext_id(str(row["title"]))
        issue_link = f"[#{row['number']}]({row['url']})"
        assignees = row.get("assignees") or []
        assignee = "unassigned" if not assignees else assignees[0]["login"]
        milestone = row.get("milestone")
        target_date = "unset"
        if milestone and milestone.get("dueOn"):
            target_date = str(milestone["dueOn"]).split("T", 1)[0]
        next_action = NEXT_ACTIONS.get(ext_id, "Update blocker issue with owner/date and evidence plan")
        lines.append(
            f"| {ext_id} | {issue_link} | {row['state']} | {assignee} | {target_date} | {row['updatedAt']} | {next_action} |"
        )

    lines.extend(
        [
            "",
            "## Execution policy",
            "",
            "- Treat all rows as release blockers until issue is closed with evidence.",
            "- Daily cadence: review issue updates, enforce owner assignment, and move stale blockers.",
            "- Escalation trigger: any blocker without owner or target date for >48h.",
            "- Daily update template: `docs/_operator/daily-external-blocker-template.md`",
            "- Escalation matrix: `docs/_operator/external-blocker-escalation-matrix.md`",
            f"- Latest daily update: `docs/_operator/{latest_daily_update}`",
            "",
            "## Automation",
            "",
            "Recommended one-command pipeline:",
            "",
            "```bash",
            "python3 backend/scripts/run_external_blocker_ops.py",
            "```",
            "",
            "Manual step-by-step (if needed):",
            "",
            "```bash",
            "python3 backend/scripts/generate_daily_external_blocker_update.py",
            "python3 backend/scripts/refresh_external_blocker_dashboard.py",
            "python3 backend/scripts/check_external_blocker_escalations.py",
            "```",
            "",
        ]
    )
    return "\n".join(lines)


def _latest_daily_update_doc() -> str:
    candidates = sorted(OPERATOR_DIR.glob("daily-external-blocker-update-*.md"))
    if not candidates:
        return "daily-external-blocker-template.md"
    return candidates[-1].name


def main() -> int:
    rows = _load_blockers()
    markdown = _render_markdown(rows)
    OUTPUT_PATH.write_text(markdown, encoding="utf-8")
    print(f"Wrote dashboard: {OUTPUT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
