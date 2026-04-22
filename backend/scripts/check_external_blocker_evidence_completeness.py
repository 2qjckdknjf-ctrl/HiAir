import json
import subprocess


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


def main() -> int:
    issues = sorted(_list_ext_issues(), key=lambda i: int(i["number"]))
    print("External blocker evidence completeness")
    all_complete = True
    for issue in issues:
        number = int(issue["number"])
        ext_id = str(issue["title"]).split(":", 1)[0]
        form = _latest_evidence_form_comment(number)
        if form is None:
            print(f"- #{number} {ext_id}: MISSING_FORM")
            all_complete = False
            continue
        if "[ADD]" in form:
            print(f"- #{number} {ext_id}: INCOMPLETE (placeholders remain)")
            all_complete = False
        else:
            print(f"- #{number} {ext_id}: COMPLETE")
    if not all_complete:
        print("Evidence package is incomplete for at least one external blocker.")
        return 1
    print("All external blocker evidence packages are complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
