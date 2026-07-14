from datetime import date
from uuid import uuid4

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator

from app.core.geo_coordinates import validate_home_coordinates
from app.models.risk import PersonaType


class SignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)


class AuthResponse(BaseModel):
    user_id: str
    access_token: str
    refresh_token: str | None = None
    token_type: str = "bearer"


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(min_length=24)


def _validate_date_of_birth(value: date | None) -> date | None:
    if value is None:
        return None
    today = date.today()
    if value >= today:
        raise ValueError("date_of_birth must be in the past")
    age = today.year - value.year - ((today.month, today.day) < (value.month, value.day))
    if age < 1 or age > 120:
        raise ValueError("date_of_birth implies an unrealistic age")
    return value


class ProfileCreateRequest(BaseModel):
    persona_type: PersonaType
    sensitivity_level: str = Field(pattern="^(low|medium|high)$")
    home_lat: float = Field(ge=-90, le=90)
    home_lon: float = Field(ge=-180, le=180)
    date_of_birth: date | None = None

    @field_validator("date_of_birth")
    @classmethod
    def validate_dob(cls, value: date | None) -> date | None:
        return _validate_date_of_birth(value)

    @model_validator(mode="after")
    def validate_coordinates(self) -> "ProfileCreateRequest":
        validate_home_coordinates(self.home_lat, self.home_lon)
        return self


class ProfileUpdateRequest(BaseModel):
    persona_type: PersonaType | None = None
    sensitivity_level: str | None = Field(default=None, pattern="^(low|medium|high)$")
    home_lat: float | None = Field(default=None, ge=-90, le=90)
    home_lon: float | None = Field(default=None, ge=-180, le=180)
    date_of_birth: date | None = None

    @field_validator("date_of_birth")
    @classmethod
    def validate_dob(cls, value: date | None) -> date | None:
        return _validate_date_of_birth(value)

    @model_validator(mode="after")
    def validate_partial_coordinates(self) -> "ProfileUpdateRequest":
        if self.home_lat is not None and self.home_lon is not None:
            validate_home_coordinates(self.home_lat, self.home_lon)
        return self


class ProfileResponse(ProfileCreateRequest):
    id: str
    user_id: str
    age_years: int | None = None

    @staticmethod
    def create(user_id: str, payload: ProfileCreateRequest) -> "ProfileResponse":
        return ProfileResponse(
            id=str(uuid4()),
            user_id=user_id,
            persona_type=payload.persona_type,
            sensitivity_level=payload.sensitivity_level,
            home_lat=payload.home_lat,
            home_lon=payload.home_lon,
            date_of_birth=payload.date_of_birth,
            age_years=_age_years_from_dob(payload.date_of_birth),
        )


def _age_years_from_dob(dob: date | None) -> int | None:
    if dob is None:
        return None
    today = date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


def age_group_from_date_of_birth(dob: date | None, persona_type: str) -> str:
    if dob is None:
        if persona_type == "child":
            return "child"
        if persona_type == "elderly":
            return "elderly"
        return "adult"
    age = _age_years_from_dob(dob)
    if age is None:
        return "adult"
    if age < 13:
        return "child"
    if age >= 65:
        return "elderly"
    return "adult"
