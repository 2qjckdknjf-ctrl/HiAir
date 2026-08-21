"""Protected-day event store — Postgres with in-memory fallback."""

from __future__ import annotations

from datetime import date
from uuid import uuid4

from psycopg import OperationalError
from psycopg.errors import UndefinedTable

from app.services.db import get_connection
from app.services.personal_adaptation_engine import ProtectedDayEvent, ProtectedDayEventType

_STORE: dict[str, list[dict]] = {}
_FORCE_MEMORY = False


def reset_store() -> None:
    _STORE.clear()


def force_memory_store(enabled: bool = True) -> None:
    global _FORCE_MEMORY
    _FORCE_MEMORY = enabled


def record_event(
    *,
    user_id: str,
    profile_id: str,
    event_type: ProtectedDayEventType,
    event_date: date | None = None,
) -> dict:
    resolved_date = event_date or date.today()
    record = {
        "id": str(uuid4()),
        "user_id": user_id,
        "profile_id": profile_id,
        "event_type": event_type.value,
        "event_date": resolved_date,
    }
    if _FORCE_MEMORY:
        _STORE.setdefault(profile_id, []).append(record)
        return record
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO protected_day_events (id, user_id, profile_id, event_type, event_date)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING id, user_id, profile_id, event_type, event_date
                    """,
                    (record["id"], user_id, profile_id, event_type.value, resolved_date),
                )
                row = cur.fetchone()
                return dict(row)
    except (UndefinedTable, OperationalError):
        _STORE.setdefault(profile_id, []).append(record)
        return record


def list_events(*, profile_id: str, user_id: str | None = None) -> list[ProtectedDayEvent]:
    if _FORCE_MEMORY:
        rows = _STORE.get(profile_id, [])
        if user_id is not None:
            rows = [row for row in rows if row["user_id"] == user_id]
        return [
            ProtectedDayEvent(
                event_type=ProtectedDayEventType(row["event_type"]),
                event_date=row["event_date"],
            )
            for row in rows
        ]
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                if user_id is None:
                    cur.execute(
                        """
                        SELECT event_type, event_date
                        FROM protected_day_events
                        WHERE profile_id = %s
                        ORDER BY event_date DESC
                        """,
                        (profile_id,),
                    )
                else:
                    cur.execute(
                        """
                        SELECT event_type, event_date
                        FROM protected_day_events
                        WHERE profile_id = %s AND user_id = %s
                        ORDER BY event_date DESC
                        """,
                        (profile_id, user_id),
                    )
                rows = cur.fetchall() or []
                return [
                    ProtectedDayEvent(
                        event_type=ProtectedDayEventType(row["event_type"]),
                        event_date=row["event_date"],
                    )
                    for row in rows
                ]
    except (UndefinedTable, OperationalError):
        rows = _STORE.get(profile_id, [])
        if user_id is not None:
            rows = [row for row in rows if row["user_id"] == user_id]
        return [
            ProtectedDayEvent(
                event_type=ProtectedDayEventType(row["event_type"]),
                event_date=row["event_date"],
            )
            for row in rows
        ]
