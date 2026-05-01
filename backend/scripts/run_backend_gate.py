import argparse
import os
import subprocess
import sys
from pathlib import Path


def _load_dotenv(env_file: Path) -> None:
    if not env_file.exists():
        return
    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("'").strip('"')
        if key and key not in os.environ:
            os.environ[key] = value


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
    parser.add_argument(
        "--skip-db",
        action="store_true",
        help="Skip database-dependent steps (init_db, retention_cleanup, smoke_db_flow).",
    )
    parser.add_argument(
        "--env-file",
        default=None,
        help="Optional dotenv file to preload into environment (defaults to backend/.env.local when present).",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    default_env = root / ".env.local"
    env_path = Path(args.env_file).expanduser() if args.env_file else default_env
    if env_path.exists():
        _load_dotenv(env_path)
        print(f"[INFO] Loaded environment from {env_path}")

    python_exe = sys.executable
    commands = [
        [python_exe, "-m", "compileall", "app", "scripts"],
        [python_exe, "scripts/check_env_security.py", "--strict"],
        [python_exe, "scripts/validate_risk_historical.py"],
    ]

    if not args.skip_db:
        commands.extend(
            [
                [python_exe, "scripts/init_db.py"],
                [python_exe, "scripts/retention_cleanup.py", "--dry-run"],
            ]
        )
    else:
        print("[INFO] --skip-db enabled: skipping init_db and retention dry-run.")

    if not args.skip_smoke and not args.skip_db:
        commands.append([python_exe, "scripts/smoke_db_flow.py"])
    elif args.skip_smoke:
        print("[INFO] --skip-smoke enabled: skipping smoke_db_flow.")
    elif args.skip_db:
        print("[INFO] --skip-db implies smoke_db_flow is skipped.")

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
