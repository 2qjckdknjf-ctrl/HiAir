import argparse
import json

from app.services.briefing_service import dispatch_due_briefings


def main() -> int:
    parser = argparse.ArgumentParser(description="Dispatch due morning briefings.")
    parser.add_argument("--dry-run", action="store_true", help="Do not send notifications, only print due users.")
    args = parser.parse_args()

    results = dispatch_due_briefings(dry_run=args.dry_run)
    print(json.dumps({"count": len(results), "dry_run": args.dry_run, "results": results}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
