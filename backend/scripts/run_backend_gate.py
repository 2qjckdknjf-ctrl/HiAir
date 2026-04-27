import argparse
import os
import subprocess
import sys
from pathlib import Path

from dotenv import load_dotenv


def _default_env_file(root: Path) -> str:
    local = root / ".env.local"
    if local.is_file():
        return str(local)
    return ".env"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run backend quality gate checks in sequence (matches `.github/workflows/backend-ci.yml` + optional preflight).",
    )
    parser.add_argument(
        "--base-url",
        default=None,
        help="Optional base URL for beta preflight. If omitted, preflight step is skipped.",
    )
    parser.add_argument(
        "--admin-token",
        default=os.getenv("NOTIFICATION_ADMIN_TOKEN", ""),
        help="Optional X-Admin-Token for beta preflight (defaults to NOTIFICATION_ADMIN_TOKEN env).",
    )
    parser.add_argument(
        "--env-file",
        default=None,
        help="Path to env file for check_env_security.py (default: .env.local if present, else .env).",
    )
    parser.add_argument(
        "--skip-smoke",
        action="store_true",
        help="Skip smoke flow execution.",
    )
    parser.add_argument(
        "--skip-pytest",
        action="store_true",
        help="Skip pytest suite.",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    python_exe = sys.executable
    env_file = args.env_file if args.env_file is not None else _default_env_file(root)
    env_path = Path(env_file)
    if not env_path.is_absolute():
        env_path = root / env_file
    if env_path.is_file():
        load_dotenv(env_path, override=False)

    commands: list[list[str]] = [
        [python_exe, "-m", "compileall", "app", "scripts"],
    ]
    if not args.skip_pytest:
        commands.append([python_exe, "-m", "pytest", "tests", "-q"])
    commands.append([python_exe, "scripts/check_env_security.py", "--env-file", env_file, "--strict"])
    commands.extend(
        [
            [python_exe, "scripts/init_db.py"],
            [python_exe, "scripts/retention_cleanup.py", "--dry-run"],
        ]
    )
    if not args.skip_smoke:
        commands.append([python_exe, "scripts/smoke_db_flow.py"])
    commands.append([python_exe, "scripts/validate_risk_historical.py"])
    if args.base_url:
        preflight = [
            python_exe,
            "scripts/beta_preflight.py",
            "--base-url",
            args.base_url,
        ]
        if args.admin_token:
            preflight.extend(["--admin-token", args.admin_token])
        commands.append(preflight)

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
