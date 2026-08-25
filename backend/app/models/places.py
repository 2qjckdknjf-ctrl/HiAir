"""HiAir 1.5 — Saved Places contracts (additive)."""

from datetime import UTC, datetime
from enum import Enum
from uuid import uuid4

from pydantic import BaseModel, Field, field_validator, model_validator

from app.core.geo_coordinates import validate_home_coordinates


class PlaceType(str, Enum):
    HOME = "home"
    WORK = "work"
    SCHOOL = "school"
    PARENTS = "parents"
    VACATION = "vacation"
    OTHER = "other"


class SavedPlaceCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    placeType: PlaceType
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    timezone: str | None = Field(default=None, min_length=1, max_length=64)

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("name must not be blank")
        return trimmed

    @model_validator(mode="after")
    def validate_coordinates(self) -> "SavedPlaceCreateRequest":
        validate_home_coordinates(self.lat, self.lon)
        return self


class SavedPlace(BaseModel):
    id: str
    userId: str
    name: str
    placeType: PlaceType
    lat: float
    lon: float
    timezone: str | None = None
    createdAt: str | None = None

    @staticmethod
    def create(user_id: str, payload: SavedPlaceCreateRequest) -> "SavedPlace":
        return SavedPlace(
            id=str(uuid4()),
            userId=user_id,
            name=payload.name,
            placeType=payload.placeType,
            lat=payload.lat,
            lon=payload.lon,
            timezone=payload.timezone,
            createdAt=datetime.now(tz=UTC).isoformat(),
        )


class SavedPlaceListResponse(BaseModel):
    places: list[SavedPlace] = Field(default_factory=list)
