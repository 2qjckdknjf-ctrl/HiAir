import argparse
import json
import os
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
BACKEND_ROOT = REPO_ROOT / "backend"


@dataclass
class EvidenceItem:
    name: str
    command: list[str]
    cwd: str
    status: str
    exit_code: int
    output_tail: str


def _run_command(name: str, command: list[str], cwd: Path, allow_failure: bool = False) -> EvidenceItem:
    completed = subprocess.run(command, cwd=cwd, check=False, capture_output=True, text=True)
    combined_output = (completed.stdout or "") + ("\n" + completed.stderr if completed.stderr else "")
    status = "DONE" if completed.returncode == 0 else "FAILED"

    if completed.returncode != 0 and allow_failure:
        lowered = combined_output.lower()
        if "connection refused" in lowered or "database unavailable" in lowered:
            status = "BLOCKED"

    tail_lines = combined_output.strip().splitlines()
    output_tail = "\n".join(tail_lines[-20:]) if tail_lines else ""

    return EvidenceItem(
        name=name,
        command=_sanitize_command(command),
        cwd=str(cwd),
        status=status,
        exit_code=completed.returncode,
        output_tail=output_tail,
    )


def _sanitize_command(command: list[str]) -> list[str]:
    sanitized = list(command)
    for index, token in enumerate(sanitized):
        if token == "--admin-token" and index + 1 < len(sanitized):
            sanitized[index + 1] = "<redacted>"
    return sanitized


def main() -> int:
    parser = argparse.ArgumentParser(description="Collect machine-readable Stage 12 verification evidence.")
    parser.add_argument(
        "--output",
        default=str(REPO_ROOT / "docs" / "_operator" / "stage12-evidence-latest.json"),
        help="Path to JSON evidence output file.",
    )
    parser.add_argument(
        "--base-url",
        default=None,
        help="Optional API base URL for running beta_preflight checks.",
    )
    parser.add_argument(
        "--admin-token",
        default=os.getenv("NOTIFICATION_ADMIN_TOKEN", ""),
        help="Admin token for protected preflight endpoints.",
    )
    parser.add_argument(
        "--skip-authenticated-checks",
        action="store_true",
        help="Pass through to beta_preflight for no-DB runs.",
    )
    args = parser.parse_args()

    output_path = Path(args.output).expanduser()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    items: list[EvidenceItem] = []
    python_exe = sys.executable

    items.append(
        _run_command(
            "pytest_full",
            [python_exe, "-m", "pytest", "-q"],
            cwd=BACKEND_ROOT,
        )
    )
    items.append(
        _run_command(
            "run_backend_gate_skip_db",
            [python_exe, "scripts/run_backend_gate.py", "--skip-db"],
            cwd=BACKEND_ROOT,
        )
    )
    items.append(
        _run_command(
            "run_backend_gate_full",
            [python_exe, "scripts/run_backend_gate.py"],
            cwd=BACKEND_ROOT,
            allow_failure=True,
        )
    )
    items.append(
        _run_command(
            "validate_risk_historical",
            [python_exe, "scripts/validate_risk_historical.py"],
            cwd=BACKEND_ROOT,
        )
    )

    if args.base_url:
        preflight_cmd = [python_exe, "scripts/beta_preflight.py", "--base-url", args.base_url]
        if args.admin_token:
            preflight_cmd.extend(["--admin-token", args.admin_token])
        if args.skip_authenticated_checks:
            preflight_cmd.append("--skip-authenticated-checks")
        items.append(
            _run_command(
                "beta_preflight",
                preflight_cmd,
                cwd=BACKEND_ROOT,
                allow_failure=True,
            )
        )

    blocked = sum(1 for item in items if item.status == "BLOCKED")
    failed = sum(1 for item in items if item.status == "FAILED")
    done = sum(1 for item in items if item.status == "DONE")

    summary = {
        "collected_at_utc": datetime.now(tz=UTC).isoformat(),
        "git_head": _git_head(),
        "counts": {
            "done": done,
            "blocked": blocked,
            "failed": failed,
            "total": len(items),
        },
        "overall_status": "FAILED" if failed > 0 else ("PARTIAL" if blocked > 0 else "DONE"),
        "items": [asdict(item) for item in items],
    }
    output_path.write_text(json.dumps(summary, ensure_ascii=True, indent=2), encoding="utf-8")
    print(f"Wrote Stage 12 evidence: {output_path}")
    print(f"Overall status: {summary['overall_status']}")

    return 1 if failed > 0 else 0


def _git_head() -> str:
    completed = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        return "unknown"
    return completed.stdout.strip()


if __name__ == "__main__":
    raise SystemExit(main())
