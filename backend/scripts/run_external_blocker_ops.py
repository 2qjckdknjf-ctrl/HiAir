import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def _run(script_name: str, *script_args: str, allow_failure: bool = False) -> int:
    script_path = ROOT / "backend" / "scripts" / script_name
    printable = " ".join((script_name, *script_args)).strip()
    print(f"[RUN] {printable}")
    completed = subprocess.run([sys.executable, str(script_path), *script_args], check=False)
    if completed.returncode != 0 and not allow_failure:
        raise SystemExit(completed.returncode)
    return completed.returncode


def main() -> int:
    strict = "--strict" in sys.argv
    notify = "--notify" in sys.argv
    _run("generate_daily_external_blocker_update.py")
    _run("refresh_external_blocker_dashboard.py")
    escalation_args = ("--notify",) if notify else ()
    _run("check_external_blocker_escalations.py", *escalation_args)
    strict_failures: list[tuple[str, int]] = []
    if strict:
        closure_rc = _run("check_external_blocker_closure_readiness.py", allow_failure=True)
        if closure_rc != 0:
            strict_failures.append(("check_external_blocker_closure_readiness.py", closure_rc))
        evidence_rc = _run("check_external_blocker_evidence_completeness.py", allow_failure=True)
        if evidence_rc != 0:
            strict_failures.append(("check_external_blocker_evidence_completeness.py", evidence_rc))
        metadata_rc = _run("check_store_metadata_packet.py", allow_failure=True)
        if metadata_rc != 0:
            strict_failures.append(("check_store_metadata_packet.py", metadata_rc))
    if strict_failures:
        print("[FAIL] External blocker ops strict gates failed:")
        for script_name, return_code in strict_failures:
            print(f"- {script_name} (exit_code={return_code})")
        return 1
    print("[OK] External blocker ops pipeline completed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
