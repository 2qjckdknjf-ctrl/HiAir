import json
import subprocess
from dataclasses import dataclass
from datetime import UTC, datetime


REPO = "2qjckdknjf-ctrl/HiAir"


@dataclass
class BlockerIssue:
    number: int
    title: str
    state: str
    url: str
    updated_at: datetime
    assignees: list[str]


def _run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True).strip()


def _load_issues() -> list[BlockerIssue]:
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
            "number,title,state,url,updatedAt,assignees",
            "--limit",
            "50",
        ]
    )
    items = json.loads(raw)
    results: list[BlockerIssue] = []
    for i in items:
        title = str(i["title"])
        if not title.startswith("EXT-"):
            continue
        results.append(
            BlockerIssue(
                number=int(i["number"]),
                title=title,
                state=str(i["state"]),
                url=str(i["url"]),
                updated_at=datetime.fromisoformat(str(i["updatedAt"]).replace("Z", "+00:00")),
                assignees=[a["login"] for a in (i.get("assignees") or [])],
            )
        )
    return sorted(results, key=lambda x: x.number)


def main() -> int:
    now = datetime.now(tz=UTC)
    issues = _load_issues()
    print(f"External blocker escalation check at {now.isoformat()}")
    for issue in issues:
        age_hours = (now - issue.updated_at).total_seconds() / 3600
        owner_state = "unassigned" if not issue.assignees else ",".join(issue.assignees)
        breached_owner = not issue.assignees and age_hours > 48
        breached_stale = age_hours > 72
        flags: list[str] = []
        if breached_owner:
            flags.append("BREACH:no-owner>48h")
        if breached_stale:
            flags.append("BREACH:stale>72h")
        flag_text = " | " + " ".join(flags) if flags else ""
        print(f"- #{issue.number} {issue.title} | owner={owner_state} | age_h={age_hours:.1f}{flag_text}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
