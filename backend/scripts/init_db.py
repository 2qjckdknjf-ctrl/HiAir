import sys
from pathlib import Path

from psycopg import connect

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.settings import settings


def main() -> None:
    sql_dir = Path(__file__).resolve().parents[1] / "sql"
    sql_files = sorted(sql_dir.glob("*.sql"))
    if not sql_files:
        raise RuntimeError(f"No SQL files found in {sql_dir}")

    with connect(settings.database_url) as conn:
        with conn.cursor() as cur:
            for sql_path in sql_files:
                sql_text = sql_path.read_text(encoding="utf-8")
                cur.execute(sql_text)
        conn.commit()
    print(f"Database schema initialized ({len(sql_files)} migrations).")


if __name__ == "__main__":
    main()
