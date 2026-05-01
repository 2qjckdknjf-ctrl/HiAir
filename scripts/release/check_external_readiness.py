#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

REQUIRED_EXTERNAL_ENV_KEYS = [
    "APPLE_TEAM_ID",
    "APP_STORE_CONNECT_APP_ID",
    "APP_REVIEW_TEST_EMAIL",
    "APP_REVIEW_TEST_PASSWORD",
    "GOOGLE_PLAY_PACKAGE_NAME",
    "PLAY_REVIEW_TEST_EMAIL",
    "PLAY_REVIEW_TEST_PASSWORD",
    "APNS_KEY_ID",
    "APNS_TEAM_ID",
    "APNS_KEY_PATH",
    "FCM_PROJECT_ID",
    "FCM_SERVICE_ACCOUNT_JSON",
    "LEGAL_PRIVACY_POLICY_URL",
    "LEGAL_TERMS_URL",
]


@dataclass
class CheckResult:
    name: str
    status: str  # DONE | MISSING | BLOCKED
    detail: str


def load_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def env_lookup(name: str, file_values: dict[str, str]) -> str:
    runtime = os.getenv(name, "").strip()
    if runtime:
        return runtime
    return file_values.get(name, "").strip()


def is_placeholder(value: str) -> bool:
    if not value:
        return True
    lowered = value.lower()
    placeholder_tokens = ("<", "changeme", "todo", "example", "placeholder", "your_")
    return any(token in lowered for token in placeholder_tokens)


def check_required_env(name: str, file_values: dict[str, str]) -> CheckResult:
    value = env_lookup(name, file_values)
    if is_placeholder(value):
        return CheckResult(name=name, status="MISSING", detail=f"{name} is empty or placeholder")
    return CheckResult(name=name, status="DONE", detail=f"{name} is set")


def check_required_file(name: str, path_value: str, root: Path) -> CheckResult:
    normalized = path_value.strip()
    if is_placeholder(normalized):
        return CheckResult(name=name, status="MISSING", detail=f"{name} path is empty or placeholder")
    path = Path(normalized)
    if not path.is_absolute():
        path = (root / path).resolve()
    if not path.exists():
        return CheckResult(name=name, status="MISSING", detail=f"{name} file not found: {path}")
    try:
        with path.open("rb") as handle:
            handle.read(1)
    except OSError as exc:
        return CheckResult(name=name, status="MISSING", detail=f"{name} file is not readable: {exc}")
    return CheckResult(name=name, status="DONE", detail=f"{name} file exists and is readable: {path}")


def check_public_url(name: str, file_values: dict[str, str]) -> CheckResult:
    value = env_lookup(name, file_values)
    if is_placeholder(value):
        return CheckResult(name=name, status="MISSING", detail=f"{name} is empty or placeholder")
    parsed = urlparse(value)
    host = (parsed.hostname or "").lower()
    if parsed.scheme not in {"http", "https"} or not host:
        return CheckResult(name=name, status="MISSING", detail=f"{name} must be a valid public URL")
    blocked_hosts = {"localhost", "127.0.0.1", "0.0.0.0"}
    if host in blocked_hosts or host.endswith(".local"):
        return CheckResult(name=name, status="MISSING", detail=f"{name} must not point to local/private host")
    return CheckResult(name=name, status="DONE", detail=f"{name} is a valid public URL")


def print_owner_actions(
    unresolved: list[CheckResult],
    file_values: dict[str, str],
    env_file: Path,
) -> None:
    missing_env_names = {
        item.name
        for item in unresolved
        if item.status == "MISSING" and item.name in REQUIRED_EXTERNAL_ENV_KEYS
    }
    needs_legal_finalization = any(
        item.name
        in {
            "LEGAL_PRIVACY_POLICY_STATUS_FINALIZATION",
            "LEGAL_TERMS_STATUS_FINALIZATION",
        }
        for item in unresolved
    )

    print("\nOwner actions to reach strict green:")
    print("- Fill runtime/local env values (do not commit secrets):")
    if missing_env_names:
        for key in REQUIRED_EXTERNAL_ENV_KEYS:
            if key in missing_env_names:
                current = env_lookup(key, file_values)
                suffix = "  # currently empty/placeholder" if is_placeholder(current) else ""
                print(f"  - {key}=<value>{suffix}")
    else:
        print("  - No missing env keys detected.")

    print(f"- Update values in runtime env or local file: {env_file}")
    print("- Keep secrets out of git (.env.local, APNS key, FCM JSON, review passwords).")

    if needs_legal_finalization:
        print("- Legal owner must finalize statuses and publish public URLs:")
        print("  - docs/06_PRIVACY_LEGAL_STATUS.md -> Privacy Policy status: DONE")
        print("  - docs/06_PRIVACY_LEGAL_STATUS.md -> Terms status: DONE")
        print("  - docs/06_PRIVACY_LEGAL_STATUS.md -> Legal: DONE")

    print("- Verify after owner updates:")
    print("  - python3 scripts/release/check_external_readiness.py --env-file backend/.env.local")
    print("  - python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local")
    print("  - scripts/release/hiair_final_gate.sh --strict-external")


def check_file_exists(path: Path, name: str) -> CheckResult:
    if not path.exists():
        return CheckResult(name=name, status="MISSING", detail=f"Missing file: {path}")
    return CheckResult(name=name, status="DONE", detail=f"File exists: {path}")


def check_contains_all(path: Path, name: str, required_tokens: list[str]) -> CheckResult:
    if not path.exists():
        return CheckResult(name=name, status="MISSING", detail=f"Missing file: {path}")
    content = path.read_text(encoding="utf-8")
    missing = [token for token in required_tokens if token.lower() not in content.lower()]
    if missing:
        return CheckResult(name=name, status="MISSING", detail=f"Missing required content markers: {', '.join(missing)}")
    return CheckResult(name=name, status="DONE", detail="All required content markers found")


def main() -> int:
    parser = argparse.ArgumentParser(description="Check external launch blockers readiness.")
    parser.add_argument("--strict", action="store_true", help="Return non-zero if any external blocker is missing.")
    parser.add_argument(
        "--env-file",
        default="backend/.env.local",
        help="Path to env file with release credentials (default: backend/.env.local).",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[2]
    env_file = Path(args.env_file)
    if not env_file.is_absolute():
        env_file = root / env_file
    file_values = load_env_file(env_file)

    credentials_results: list[CheckResult] = []
    qa_results: list[CheckResult] = []
    store_results: list[CheckResult] = []
    legal_results: list[CheckResult] = []

    # Apple / App Store
    credentials_results.append(check_required_env("APPLE_TEAM_ID", file_values))
    credentials_results.append(check_required_env("APP_STORE_CONNECT_APP_ID", file_values))
    credentials_results.append(check_required_env("APP_REVIEW_TEST_EMAIL", file_values))
    credentials_results.append(check_required_env("APP_REVIEW_TEST_PASSWORD", file_values))

    # Google Play
    credentials_results.append(check_required_env("GOOGLE_PLAY_PACKAGE_NAME", file_values))
    credentials_results.append(check_required_env("PLAY_REVIEW_TEST_EMAIL", file_values))
    credentials_results.append(check_required_env("PLAY_REVIEW_TEST_PASSWORD", file_values))

    # Push production credentials
    credentials_results.append(check_required_env("APNS_KEY_ID", file_values))
    credentials_results.append(check_required_env("APNS_TEAM_ID", file_values))
    apns_key_path = env_lookup("APNS_KEY_PATH", file_values)
    credentials_results.append(check_required_file("APNS_KEY_PATH", apns_key_path, root))

    credentials_results.append(check_required_env("FCM_PROJECT_ID", file_values))
    fcm_json_path = env_lookup("FCM_SERVICE_ACCOUNT_JSON", file_values)
    credentials_results.append(check_required_file("FCM_SERVICE_ACCOUNT_JSON", fcm_json_path, root))

    # Legal/public links
    credentials_results.append(check_public_url("LEGAL_PRIVACY_POLICY_URL", file_values))
    credentials_results.append(check_public_url("LEGAL_TERMS_URL", file_values))

    # QA evidence
    qa_report = root / "docs/release/qa/REAL_DEVICE_QA_REPORT.md"
    qa_results.append(check_file_exists(qa_report, "REAL_DEVICE_QA_REPORT"))
    qa_results.append(
        check_contains_all(
            qa_report,
            "REAL_DEVICE_QA_REPORT_REQUIRED_CONTENT",
            [
                "iOS device matrix",
                "Android device matrix",
                "App version",
                "Build number",
                "Critical flow",
                "Result",
                "Open issues",
                "Owner",
                "Status",
                "install/open app",
                "onboarding",
                "login",
                "logout",
                "session restore",
                "dashboard load",
                "planner load",
                "symptom log create",
                "insights load",
                "morning briefing settings",
                "notification permission",
                "push token registration",
                "privacy export",
                "account delete",
                "offline/poor network",
                "RU localization",
                "EN localization",
            ],
        )
    )

    # Store handoff artifacts
    store_results.append(check_file_exists(root / "docs/release/store/APP_STORE_HANDOFF.md", "STORE_APPLE_METADATA_CHECKLIST"))
    store_results.append(check_file_exists(root / "docs/release/store/GOOGLE_PLAY_HANDOFF.md", "STORE_GOOGLE_METADATA_CHECKLIST"))
    store_results.append(check_file_exists(root / "docs/release/store/PRIVACY_LABELS.md", "STORE_PRIVACY_LABELS_DATA_SAFETY_DRAFT"))
    store_results.append(check_file_exists(root / "docs/release/store/DATA_SAFETY.md", "STORE_DATA_SAFETY_DRAFT"))
    store_results.append(check_file_exists(root / "docs/release/store/REVIEWER_NOTES.md", "STORE_REVIEWER_NOTES"))
    store_results.append(check_file_exists(root / "docs/release/store/BETA_TESTING_PLAN.md", "STORE_BETA_TESTING_PLAN"))
    store_results.append(check_file_exists(root / "docs/release/store/SCREENSHOT_CHECKLIST.md", "STORE_SCREENSHOT_CHECKLIST"))

    # Legal status markers and disclaimers
    legal_status_doc = root / "docs/06_PRIVACY_LEGAL_STATUS.md"
    legal_results.append(
        check_contains_all(
            legal_status_doc,
            "LEGAL_STATUS_FIELDS",
            ["Privacy Policy status", "Terms status"],
        )
    )
    wellness_doc = root / "docs/release/store/WELLNESS_DISCLAIMER.md"
    legal_results.append(
        check_contains_all(
            wellness_doc,
            "LEGAL_WELLNESS_NON_MEDICAL_DISCLAIMER",
            ["medical device", "diagnosis", "treatment"],
        )
    )
    legal_results.append(
        check_contains_all(
            wellness_doc,
            "LEGAL_EMERGENCY_DISCLAIMER",
            ["emergenc"],
        )
    )

    # If legal status is explicitly not done, mark as BLOCKED even when fields exist.
    if legal_status_doc.exists():
        legal_text = legal_status_doc.read_text(encoding="utf-8").lower()
        for marker_name in ("privacy policy status", "terms status"):
            idx = legal_text.find(marker_name)
            if idx >= 0:
                snippet = legal_text[idx : idx + 120]
                if any(token in snippet for token in ("blocked", "pending", "draft", "missing")):
                    legal_results.append(
                        CheckResult(
                            name=f"LEGAL_{marker_name.upper().replace(' ', '_')}_FINALIZATION",
                            status="BLOCKED",
                            detail=f"{marker_name} is not finalized (owner/legal action required)",
                        )
                    )

    all_results = credentials_results + qa_results + store_results + legal_results

    print("External readiness check:")
    print("A) Credentials")
    for item in credentials_results:
        print(f"- [{item.status}] {item.name}: {item.detail}")
    print("B) QA evidence")
    for item in qa_results:
        print(f"- [{item.status}] {item.name}: {item.detail}")
    print("C) Store handoff")
    for item in store_results:
        print(f"- [{item.status}] {item.name}: {item.detail}")
    print("D) Legal")
    for item in legal_results:
        print(f"- [{item.status}] {item.name}: {item.detail}")

    unresolved = [item for item in all_results if item.status in {"MISSING", "BLOCKED"}]
    if unresolved:
        missing_count = sum(1 for item in unresolved if item.status == "MISSING")
        blocked_count = sum(1 for item in unresolved if item.status == "BLOCKED")
        print(f"\nSummary: MISSING={missing_count}, BLOCKED={blocked_count}, DONE={len(all_results) - len(unresolved)}")
        print_owner_actions(unresolved=unresolved, file_values=file_values, env_file=env_file)
        return 1 if args.strict else 0
    print("\nSummary: all external items are ready.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
