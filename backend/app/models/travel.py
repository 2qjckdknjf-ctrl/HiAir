"""HiAir 1.5 travel mode — temporary location override via a saved place."""

from __future__ import annotations

from datetime import datetime, timezone

from pydantic import BaseModel, Field


class TravelSession(BaseModel):
    active: bool = False
    placeId: str | None = None
    placeName: str | None = None
    lat: float | None = None
    lon: float | None = None
    timezone: str | None = None
    until: str | None = None
    source: str = "home"


class TravelSessionStartRequest(BaseModel):
    placeId: str = Field(min_length=1)
    until: str | None = None


def parse_until(value: str | None) -> datetime | None:
    if value is None or not value.strip():
        return None
    text = value.strip().replace("Z", "+00:00")
    parsed = datetime.fromisoformat(text)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)
