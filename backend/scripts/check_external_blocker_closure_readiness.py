import json
import re
import subprocess


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


def main() -> int:
    numbers = _list_ext_issue_numbers()
    print("External blocker closure readiness")
    all_ready = True
    for n in numbers:
        body = _issue_body(n)
        done, total = _count_checkboxes(body)
        readiness = "READY" if total > 0 and done == total else "NOT_READY"
        if readiness != "READY":
            all_ready = False
        print(f"- #{n}: {readiness} ({done}/{total} checkboxes completed)")
    if not all_ready:
        print("At least one blocker issue is not closure-ready.")
        return 1
    print("All blocker issues are closure-ready.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
