import json
import subprocess
from datetime import UTC, datetime
from pathlib import Path


REPO = "2qjckdknjf-ctrl/HiAir"
OPERATOR_DIR = Path(__file__).resolve().parents[2] / "docs" / "_operator"


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
            "number,title,state,assignees,updatedAt,url,milestone",
            "--limit",
            "50",
        ]
    )
    return json.loads(raw)


def _ext_id(title: str) -> str:
    if ":" not in title:
        return "EXT-UNK"
    return title.split(":", 1)[0].strip()


def main() -> int:
    today = datetime.now(tz=UTC).strftime("%Y-%m-%d")
    output = OPERATOR_DIR / f"daily-external-blocker-update-{today}.md"
    blockers = [b for b in _load_blockers() if _ext_id(str(b["title"])).startswith("EXT-")]
    blockers.sort(key=lambda item: int(item["number"]))
    unassigned_ids: list[str] = []
    unset_date_ids: list[str] = []

    lines = [f"# Daily External Blocker Update ({today})", "", "## Snapshot", ""]
    for b in blockers:
        ext = _ext_id(str(b["title"]))
        assignees = b.get("assignees") or []
        owner = "unassigned" if not assignees else assignees[0]["login"]
        milestone = b.get("milestone")
        target_date = "unset"
        if milestone and milestone.get("dueOn"):
            target_date = str(milestone["dueOn"]).split("T", 1)[0]
        else:
            unset_date_ids.append(ext)
        if owner == "unassigned":
            unassigned_ids.append(ext)
        lines.append(f"- {ext} (#{b['number']}): {b['state']} / owner: {owner} / date: {target_date}")

    lines.extend(
        [
            "",
            "## Changes since last update",
            "",
            "- Dashboard refreshed from live GitHub issue state.",
            "- Escalation state preserved for unresolved owner/date blockers.",
            "",
            "## Escalations applied",
            "",
            "- Any external blocker without owner/date beyond threshold remains escalated in issue thread and #7.",
            "- Closure-readiness gate remains NOT_READY until final evidence/signoff checkboxes are completed.",
            "",
            "## Next 24h actions",
            "",
            f"1. Assign owners for unresolved items: {', '.join(unassigned_ids) if unassigned_ids else 'none'}",
            f"2. Set target dates for unresolved items: {', '.join(unset_date_ids) if unset_date_ids else 'none'}",
            "3. Attach final external proof artifacts and complete closure checkboxes in each EXT issue.",
            "",
        ]
    )
    output.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote daily update: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
