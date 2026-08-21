"""In-memory saved places store (HiAir 1.5 v0 — no weather/forecast)."""

from __future__ import annotations

from app.models.places import SavedPlace, SavedPlaceCreateRequest

_STORE: dict[str, dict[str, SavedPlace]] = {}


def reset_store() -> None:
    """Clear all saved places — test helper only."""
    _STORE.clear()


def create_place(*, user_id: str, payload: SavedPlaceCreateRequest) -> SavedPlace:
    place = SavedPlace.create(user_id=user_id, payload=payload)
    user_places = _STORE.setdefault(user_id, {})
    user_places[place.id] = place
    return place


def list_places(*, user_id: str) -> list[SavedPlace]:
    user_places = _STORE.get(user_id, {})
    return sorted(user_places.values(), key=lambda place: place.createdAt or "")


def delete_place(*, user_id: str, place_id: str) -> bool:
    user_places = _STORE.get(user_id)
    if not user_places or place_id not in user_places:
        return False
    del user_places[place_id]
    if not user_places:
        _STORE.pop(user_id, None)
    return True
