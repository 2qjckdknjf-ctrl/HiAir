import json
import re
import subprocess
import sys
from pathlib import Path


REPO = "2qjckdknjf-ctrl/HiAir"


def _run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True).strip()


def _list_ext_issue_numbers() -> list[int]:
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
            "number,title",
            "--limit",
            "50",
        ]
    )
    issues = json.loads(raw)
    numbers: list[int] = []
    for issue in issues:
        title = str(issue["title"])
        if title.startswith("EXT-"):
            numbers.append(int(issue["number"]))
    return sorted(numbers)


def _issue_body(number: int) -> str:
    raw = _run(["gh", "issue", "view", str(number), "--repo", REPO, "--json", "body"])
    return json.loads(raw)["body"]


def _count_checkboxes(body: str) -> tuple[int, int]:
    total = len(re.findall(r"- \[(?: |x)\]", body))
    done = len(re.findall(r"- \[x\]", body))
    return done, total


def _write_json_report(path: Path, rows: list[dict[str, object]], all_ready: bool) -> None:
    report = {
        "gate": "closure-readiness",
        "all_ready": all_ready,
        "rows": rows,
    }
    path.write_text(json.dumps(report, ensure_ascii=True, indent=2), encoding="utf-8")


def main() -> int:
    json_output: Path | None = None
    if "--json-output" in sys.argv:
        idx = sys.argv.index("--json-output")
        try:
            json_output = Path(sys.argv[idx + 1])
        except IndexError:
            raise SystemExit("--json-output requires a file path")
    numbers = _list_ext_issue_numbers()
    print("External blocker closure readiness")
    all_ready = True
    rows: list[dict[str, object]] = []
    for n in numbers:
        body = _issue_body(n)
        done, total = _count_checkboxes(body)
        readiness = "READY" if total > 0 and done == total else "NOT_READY"
        if readiness != "READY":
            all_ready = False
        rows.append(
            {
                "issue_number": n,
                "readiness": readiness,
                "checkboxes_done": done,
                "checkboxes_total": total,
            }
        )
        print(f"- #{n}: {readiness} ({done}/{total} checkboxes completed)")
    if json_output is not None:
        _write_json_report(json_output, rows, all_ready)
    if not all_ready:
        print("At least one blocker issue is not closure-ready.")
        return 1
    print("All blocker issues are closure-ready.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
