import argparse
import json
import sys
from datetime import UTC, datetime
from dataclasses import dataclass
from pathlib import Path

from psycopg import connect

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.settings import settings


@dataclass
class CleanupResult:
    table: str
    days: int
    would_delete: int
    deleted: int


def main() -> int:
    parser = argparse.ArgumentParser(description="Run retention cleanup for operational tables.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Only show how many rows would be deleted.",
    )
    parser.add_argument(
        "--json-output",
        default="",
        help="Optional file path to write machine-readable cleanup report.",
    )
    args = parser.parse_args()

    plans = [
        ("notification_delivery_attempts", "created_at", settings.retention_notification_delivery_attempts_days, ""),
        ("notification_events", "created_at", settings.retention_notification_events_days, "AND profile_id IS NULL"),
        ("subscription_webhook_events", "received_at", settings.retention_subscription_webhook_events_days, ""),
        ("notification_secret_rotation_events", "created_at", settings.retention_secret_rotation_events_days, ""),
    ]

    results: list[CleanupResult] = []
    with connect(settings.database_url) as conn:
        with conn.cursor() as cur:
            for table, column, days, extra_where in plans:
                if days < 1:
                    raise ValueError(f"{table}: retention days must be >= 1")
                count_query = f"""
                    SELECT COUNT(*) AS total
                    FROM {table}
                    WHERE {column} < NOW() - make_interval(days => %s)
                    {extra_where}
                """
                cur.execute(count_query, (days,))
                row = cur.fetchone()
                would_delete = int(row[0] if row is not None else 0)

                deleted = 0
                if not args.dry_run:
                    delete_query = f"""
                        DELETE FROM {table}
                        WHERE {column} < NOW() - make_interval(days => %s)
                        {extra_where}
                    """
                    cur.execute(delete_query, (days,))
                    deleted = cur.rowcount

                results.append(
                    CleanupResult(
                        table=table,
                        days=days,
                        would_delete=would_delete,
                        deleted=deleted,
                    )
                )
        conn.commit()

    for item in results:
        if args.dry_run:
            print(f"[DRY-RUN] {item.table}: would_delete={item.would_delete}, retention_days={item.days}")
        else:
            print(
                f"[CLEANUP] {item.table}: deleted={item.deleted}, "
                f"would_delete_before_run={item.would_delete}, retention_days={item.days}"
            )

    if args.json_output:
        report = {
            "generated_at": datetime.now(tz=UTC).isoformat(),
            "dry_run": bool(args.dry_run),
            "results": [
                {
                    "table": item.table,
                    "retention_days": item.days,
                    "would_delete": item.would_delete,
                    "deleted": item.deleted,
                }
                for item in results
            ],
        }
        Path(args.json_output).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"[REPORT] Wrote JSON report to {args.json_output}")

    print("Retention cleanup completed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
