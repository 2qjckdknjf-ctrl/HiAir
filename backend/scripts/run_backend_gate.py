import argparse
import subprocess
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Run backend quality gate checks in sequence.")
    parser.add_argument(
        "--base-url",
        default=None,
        help="Optional base URL for beta preflight. If omitted, preflight step is skipped.",
    )
    parser.add_argument(
        "--skip-smoke",
        action="store_true",
        help="Skip smoke flow execution.",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    python_exe = sys.executable
    commands = [
        [python_exe, "-m", "compileall", "app", "scripts"],
        [python_exe, "scripts/check_env_security.py", "--strict"],
        [python_exe, "scripts/init_db.py"],
        [python_exe, "scripts/retention_cleanup.py", "--dry-run"],
        [python_exe, "scripts/validate_risk_historical.py"],
    ]
    if not args.skip_smoke:
        commands.append([python_exe, "scripts/smoke_db_flow.py"])
    if args.base_url:
        commands.append([python_exe, "scripts/beta_preflight.py", "--base-url", args.base_url])

    for cmd in commands:
        print(f"\n>>> Running: {' '.join(cmd)}")
        run = subprocess.run(cmd, cwd=root)
        if run.returncode != 0:
            print(f"Command failed with exit code {run.returncode}: {' '.join(cmd)}")
            return run.returncode

    print("\nBackend gate passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
