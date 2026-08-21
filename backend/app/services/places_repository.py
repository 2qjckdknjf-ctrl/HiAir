"""Saved places repository — Postgres when available, in-memory fallback for tests/dev."""

from __future__ import annotations

from uuid import uuid4

from psycopg import OperationalError
from psycopg.errors import UndefinedTable

from app.models.places import PlaceType, SavedPlace, SavedPlaceCreateRequest
from app.services.db import get_connection

_STORE: dict[str, dict[str, SavedPlace]] = {}
_FORCE_MEMORY = False


def reset_store() -> None:
    """Clear in-memory saved places — test helper only."""
    _STORE.clear()


def force_memory_store(enabled: bool = True) -> None:
    """Force in-memory mode (unit tests)."""
    global _FORCE_MEMORY
    _FORCE_MEMORY = enabled


def _row_to_place(row: dict) -> SavedPlace:
    created = row.get("created_at")
    return SavedPlace(
        id=str(row["id"]),
        userId=str(row["user_id"]),
        name=row["name"],
        placeType=PlaceType(row["place_type"]),
        lat=float(row["lat"]),
        lon=float(row["lon"]),
        timezone=row.get("timezone"),
        createdAt=created.isoformat() if hasattr(created, "isoformat") else created,
    )


def _create_memory(*, user_id: str, payload: SavedPlaceCreateRequest) -> SavedPlace:
    place = SavedPlace.create(user_id=user_id, payload=payload)
    user_places = _STORE.setdefault(user_id, {})
    user_places[place.id] = place
    return place


def _list_memory(*, user_id: str) -> list[SavedPlace]:
    user_places = _STORE.get(user_id, {})
    return sorted(user_places.values(), key=lambda place: place.createdAt or "")


def _delete_memory(*, user_id: str, place_id: str) -> bool:
    user_places = _STORE.get(user_id)
    if not user_places or place_id not in user_places:
        return False
    del user_places[place_id]
    if not user_places:
        _STORE.pop(user_id, None)
    return True


def create_place(*, user_id: str, payload: SavedPlaceCreateRequest) -> SavedPlace:
    if _FORCE_MEMORY:
        return _create_memory(user_id=user_id, payload=payload)
    place_id = str(uuid4())
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO saved_places (id, user_id, name, place_type, lat, lon, timezone)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING id, user_id, name, place_type, lat, lon, timezone, created_at
                    """,
                    (
                        place_id,
                        user_id,
                        payload.name,
                        payload.placeType.value,
                        payload.lat,
                        payload.lon,
                        payload.timezone,
                    ),
                )
                row = cur.fetchone()
                return _row_to_place(dict(row))
    except (UndefinedTable, OperationalError):
        return _create_memory(user_id=user_id, payload=payload)


def list_places(*, user_id: str) -> list[SavedPlace]:
    if _FORCE_MEMORY:
        return _list_memory(user_id=user_id)
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, user_id, name, place_type, lat, lon, timezone, created_at
                    FROM saved_places
                    WHERE user_id = %s
                    ORDER BY created_at DESC
                    """,
                    (user_id,),
                )
                rows = cur.fetchall() or []
                return [_row_to_place(dict(row)) for row in rows]
    except (UndefinedTable, OperationalError):
        return _list_memory(user_id=user_id)


def get_place(*, user_id: str, place_id: str) -> SavedPlace | None:
    if _FORCE_MEMORY:
        return _STORE.get(user_id, {}).get(place_id)
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, user_id, name, place_type, lat, lon, timezone, created_at
                    FROM saved_places
                    WHERE user_id = %s AND id = %s
                    """,
                    (user_id, place_id),
                )
                row = cur.fetchone()
                return _row_to_place(dict(row)) if row else None
    except (UndefinedTable, OperationalError):
        return _STORE.get(user_id, {}).get(place_id)


def delete_place(*, user_id: str, place_id: str) -> bool:
    if _FORCE_MEMORY:
        return _delete_memory(user_id=user_id, place_id=place_id)
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "DELETE FROM saved_places WHERE user_id = %s AND id = %s",
                    (user_id, place_id),
                )
                return cur.rowcount > 0
    except (UndefinedTable, OperationalError):
        return _delete_memory(user_id=user_id, place_id=place_id)
