import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def _run(script_name: str) -> None:
    script_path = ROOT / "backend" / "scripts" / script_name
    print(f"[RUN] {script_name}")
    subprocess.check_call([sys.executable, str(script_path)])


def main() -> int:
    strict = "--strict" in sys.argv
    _run("generate_daily_external_blocker_update.py")
    _run("refresh_external_blocker_dashboard.py")
    _run("check_external_blocker_escalations.py")
    if strict:
        _run("check_external_blocker_closure_readiness.py")
        _run("check_external_blocker_evidence_completeness.py")
    print("[OK] External blocker ops pipeline completed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
