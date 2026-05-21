import sys
from pathlib import Path

from psycopg import connect

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.settings import settings


def _ensure_migrations_table(cur) -> None:
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS schema_migrations (
            migration_name TEXT PRIMARY KEY,
            applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        """
    )


def _applied_migrations(cur) -> set[str]:
    cur.execute("SELECT migration_name FROM schema_migrations")
    return {row[0] for row in cur.fetchall()}


def main() -> None:
    sql_dir = Path(__file__).resolve().parents[1] / "sql"
    sql_files = sorted(sql_dir.glob("*.sql"))
    if not sql_files:
        raise RuntimeError(f"No SQL files found in {sql_dir}")

    applied_count = 0
    with connect(settings.database_url) as conn:
        with conn.cursor() as cur:
            _ensure_migrations_table(cur)
            applied = _applied_migrations(cur)
            for sql_path in sql_files:
                migration_name = sql_path.name
                if migration_name in applied:
                    continue
                sql_text = sql_path.read_text(encoding="utf-8")
                cur.execute(sql_text)
                cur.execute(
                    "INSERT INTO schema_migrations (migration_name) VALUES (%s)",
                    (migration_name,),
                )
                applied_count += 1
        conn.commit()
    print(f"Database schema initialized ({applied_count} newly applied migrations).")


if __name__ == "__main__":
    main()
