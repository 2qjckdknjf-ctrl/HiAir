import re
from pathlib import Path

from scripts.init_db import SUPABASE_AUTH_MIGRATIONS


SQL_DIR = Path(__file__).resolve().parents[1] / "sql"


def _executable_sql(sql: str) -> str:
    """Strip SQL comments before looking for executable Supabase auth references."""
    without_block_comments = re.sub(r"/\*.*?\*/", "", sql, flags=re.DOTALL)
    executable_lines = [
        line.split("--", 1)[0]
        for line in without_block_comments.splitlines()
    ]
    return "\n".join(executable_lines).lower()


def test_auth_dependent_sql_is_registered_for_vanilla_postgres_gate() -> None:
    """Any migration using Supabase auth objects must be skipped in vanilla CI DBs."""
    auth_dependent: set[str] = set()
    for sql_path in SQL_DIR.glob("*.sql"):
        sql = _executable_sql(sql_path.read_text(encoding="utf-8"))
        if "auth.uid()" in sql or "auth.users" in sql:
            auth_dependent.add(sql_path.name)

    missing = auth_dependent - SUPABASE_AUTH_MIGRATIONS
    assert not missing, f"Auth-dependent migrations missing from init_db gate: {sorted(missing)}"
