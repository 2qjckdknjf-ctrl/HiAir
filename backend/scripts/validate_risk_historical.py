import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.risk_validation_service import run_historical_validation


def main() -> None:
    result = run_historical_validation()
    print(f"passed: {result.passed}")
    print(f"cases: {result.passed_cases}/{result.total_cases}")
    if result.failed_case_ids:
        print("failed_case_ids:", ", ".join(result.failed_case_ids))
    for case in result.cases:
        print(
            f"{case.case_id}: score={case.score} level={case.level} "
            f"expected_min={case.expected_min_level} passed={case.passed}"
        )
    if not result.passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
