import json
import subprocess
import sys
from pathlib import Path


REPO = "2qjckdknjf-ctrl/HiAir"


def _run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True).strip()


def _list_ext_issues() -> list[dict[str, object]]:
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
    return [i for i in issues if str(i["title"]).startswith("EXT-")]


def _latest_evidence_form_comment(issue_number: int) -> str | None:
    raw = _run(
        [
            "gh",
            "issue",
            "view",
            str(issue_number),
            "--repo",
            REPO,
            "--json",
            "comments",
        ]
    )
    comments = json.loads(raw).get("comments") or []
    for comment in reversed(comments):
        body = str(comment.get("body", ""))
        if "Final evidence submission form" in body:
            return body
    return None


def _write_json_report(path: Path, rows: list[dict[str, object]], all_complete: bool) -> None:
    report = {
        "gate": "evidence-completeness",
        "all_complete": all_complete,
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
    issues = sorted(_list_ext_issues(), key=lambda i: int(i["number"]))
    print("External blocker evidence completeness")
    all_complete = True
    rows: list[dict[str, object]] = []
    for issue in issues:
        number = int(issue["number"])
        ext_id = str(issue["title"]).split(":", 1)[0]
        form = _latest_evidence_form_comment(number)
        if form is None:
            print(f"- #{number} {ext_id}: MISSING_FORM")
            all_complete = False
            rows.append(
                {
                    "issue_number": number,
                    "ext_id": ext_id,
                    "status": "MISSING_FORM",
                }
            )
            continue
        if "[ADD]" in form:
            print(f"- #{number} {ext_id}: INCOMPLETE (placeholders remain)")
            all_complete = False
            rows.append(
                {
                    "issue_number": number,
                    "ext_id": ext_id,
                    "status": "INCOMPLETE",
                }
            )
        else:
            print(f"- #{number} {ext_id}: COMPLETE")
            rows.append(
                {
                    "issue_number": number,
                    "ext_id": ext_id,
                    "status": "COMPLETE",
                }
            )
    if json_output is not None:
        _write_json_report(json_output, rows, all_complete)
    if not all_complete:
        print("Evidence package is incomplete for at least one external blocker.")
        return 1
    print("All external blocker evidence packages are complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
