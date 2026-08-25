"""Schema contract after clean init_db on portable PostgreSQL."""

from __future__ import annotations

from pathlib import Path

import pytest
from psycopg import connect

from app.core.settings import settings
from scripts import init_db as init_db_module

EXPECTED_TABLES = {
    "account_deletion_operations",
    "account_deletion_stage_events",
    "auth_refresh_tokens",
    "briefing_schedule",
    "custom_symptoms",
    "family_member_links",
    "health_data_consents",
    "health_insights",
    "profiles",
    "protected_day_events",
    "saved_places",
    "schema_migrations",
    "symptom_favorites",
    "symptom_logs",
    "user_settings",
    "user_subscriptions",
    "users",
    "wearable_daily_summaries",
    "wearable_hourly_summaries",
    "wearable_metric_daily",
    "wearable_sleep_summaries",
    "wearable_sync_state",
}


@pytest.fixture(scope="module")
def schema_conn():
    init_db_module.main()
    conn = connect(settings.database_url)
    yield conn
    conn.close()


def _table_names(conn) -> set[str]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_type = 'BASE TABLE'
            """
        )
        rows = cur.fetchall()
        names: set[str] = set()
        for row in rows:
            if isinstance(row, dict):
                value = row["table_name"]
            else:
                value = row[0]
            if isinstance(value, bytes):
                value = value.decode("utf-8")
            names.add(str(value))
        return names


def test_expected_core_tables_exist(schema_conn) -> None:
    names = _table_names(schema_conn)
    missing = sorted(EXPECTED_TABLES - names)
    assert not missing, f"Missing tables after init_db: {missing}"


def test_wearable_tables_have_user_id_column(schema_conn) -> None:
    tables = (
        "health_data_consents",
        "wearable_daily_summaries",
        "wearable_hourly_summaries",
        "wearable_metric_daily",
        "wearable_sleep_summaries",
        "wearable_sync_state",
    )
    with schema_conn.cursor() as cur:
        for table in tables:
            cur.execute(
                """
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = %s
                  AND column_name = 'user_id'
                """,
                (table,),
            )
            assert cur.fetchone(), f"{table}.user_id missing"


def test_supabase_migrations_are_skipped_without_auth_schema(schema_conn) -> None:
    with schema_conn.cursor() as cur:
        cur.execute("SELECT migration_name FROM schema_migrations")
        applied = {row[0] for row in cur.fetchall()}
    for migration in init_db_module.SUPABASE_AUTH_MIGRATIONS:
        assert migration not in applied


def test_portable_migrations_include_wearable_and_health_intelligence() -> None:
    sql_dir = Path(__file__).resolve().parents[1] / "sql"
    assert (sql_dir / "014_wearable_activity.sql").is_file()
    assert (sql_dir / "018_health_intelligence.sql").is_file()
    wearable = (sql_dir / "014_wearable_activity.sql").read_text(encoding="utf-8")
    health = (sql_dir / "018_health_intelligence.sql").read_text(encoding="utf-8")
    assert "auth.uid" not in wearable
    assert "auth.uid" not in health
