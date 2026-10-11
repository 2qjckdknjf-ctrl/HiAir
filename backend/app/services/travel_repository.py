"""Travel mode repository — temporary location override on user_settings."""

from __future__ import annotations

from datetime import datetime, timezone

from psycopg import OperationalError
from psycopg.errors import UndefinedColumn, UndefinedTable

from app.models.travel import TravelSession
import app.services.places_repository as places_repository
from app.services.db import get_connection

_MEMORY: dict[str, dict] = {}
_FORCE_MEMORY = False


def reset_store() -> None:
    _MEMORY.clear()


def force_memory_store(enabled: bool = True) -> None:
    global _FORCE_MEMORY
    _FORCE_MEMORY = enabled


def _is_active(until: datetime | None) -> bool:
    if until is None:
        return True
    now = datetime.now(timezone.utc)
    if until.tzinfo is None:
        until = until.replace(tzinfo=timezone.utc)
    return until > now


def _session_from_place(place, *, until: datetime | None) -> TravelSession:
    until_text = until.isoformat() if until is not None else None
    return TravelSession(
        active=True,
        placeId=place.id,
        placeName=place.name,
        lat=place.lat,
        lon=place.lon,
        timezone=place.timezone,
        until=until_text,
        source="travel",
    )


def get_travel_session(user_id: str) -> TravelSession:
    if _FORCE_MEMORY:
        row = _MEMORY.get(user_id)
        if not row or not row.get("place_id"):
            return TravelSession(active=False, source="home")
        until = row.get("until")
        if not _is_active(until):
            clear_travel_session(user_id)
            return TravelSession(active=False, source="home")
        place = places_repository.get_place(user_id=user_id, place_id=row["place_id"])
        if place is None:
            clear_travel_session(user_id)
            return TravelSession(active=False, source="home")
        return _session_from_place(place, until=until)

    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT travel_place_id, travel_until
                    FROM user_settings
                    WHERE user_id = %s
                    """,
                    (user_id,),
                )
                row = cur.fetchone()
        if row is None or row.get("travel_place_id") is None:
            return TravelSession(active=False, source="home")
        until = row.get("travel_until")
        if until is not None and not _is_active(until):
            clear_travel_session(user_id)
            return TravelSession(active=False, source="home")
        place = places_repository.get_place(user_id=user_id, place_id=str(row["travel_place_id"]))
        if place is None:
            clear_travel_session(user_id)
            return TravelSession(active=False, source="home")
        return _session_from_place(place, until=until)
    except (UndefinedTable, UndefinedColumn, OperationalError):
        row = _MEMORY.get(user_id)
        if not row or not row.get("place_id"):
            return TravelSession(active=False, source="home")
        place = places_repository.get_place(user_id=user_id, place_id=row["place_id"])
        if place is None:
            return TravelSession(active=False, source="home")
        return _session_from_place(place, until=row.get("until"))


def start_travel_session(user_id: str, *, place_id: str, until: datetime | None) -> TravelSession:
    place = places_repository.get_place(user_id=user_id, place_id=place_id)
    if place is None:
        raise ValueError("Saved place not found")
    if until is not None and not _is_active(until):
        raise ValueError("travel until must be in the future")

    if _FORCE_MEMORY:
        _MEMORY[user_id] = {"place_id": place_id, "until": until}
        return _session_from_place(place, until=until)

    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO user_settings (user_id, travel_place_id, travel_until, updated_at)
                    VALUES (%s, %s, %s, NOW())
                    ON CONFLICT (user_id) DO UPDATE SET
                        travel_place_id = EXCLUDED.travel_place_id,
                        travel_until = EXCLUDED.travel_until,
                        updated_at = NOW()
                    """,
                    (user_id, place_id, until),
                )
        return _session_from_place(place, until=until)
    except (UndefinedTable, UndefinedColumn, OperationalError):
        _MEMORY[user_id] = {"place_id": place_id, "until": until}
        return _session_from_place(place, until=until)


def clear_travel_session(user_id: str) -> TravelSession:
    _MEMORY.pop(user_id, None)
    if _FORCE_MEMORY:
        return TravelSession(active=False, source="home")
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE user_settings
                    SET travel_place_id = NULL,
                        travel_until = NULL,
                        updated_at = NOW()
                    WHERE user_id = %s
                    """,
                    (user_id,),
                )
    except (UndefinedTable, UndefinedColumn, OperationalError):
        pass
    return TravelSession(active=False, source="home")
