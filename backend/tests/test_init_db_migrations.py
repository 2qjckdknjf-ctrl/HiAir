"""Verify clean PostgreSQL initialization without Supabase auth schema."""

from pathlib import Path

from scripts import init_db as init_db_module


def test_auth_gated_migrations_include_saved_places_rls() -> None:
    assert "025_supabase_table_rls.sql" in init_db_module.SUPABASE_AUTH_MIGRATIONS


def test_saved_places_migration_has_no_auth_uid_reference() -> None:
    sql_dir = Path(__file__).resolve().parents[1] / "sql"
    saved_places = (sql_dir / "021_saved_places.sql").read_text(encoding="utf-8")
    assert "auth.uid" not in saved_places


def test_supabase_rls_migration_requires_auth_uid() -> None:
    sql_dir = Path(__file__).resolve().parents[1] / "sql"
    rls_sql = (sql_dir / "025_supabase_table_rls.sql").read_text(encoding="utf-8")
    assert "auth.uid" in rls_sql
