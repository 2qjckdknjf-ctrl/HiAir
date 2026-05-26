from uuid import uuid4

from pydantic import BaseModel, EmailStr, Field

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


class ProfileCreateRequest(BaseModel):
    persona_type: PersonaType
    sensitivity_level: str = Field(pattern="^(low|medium|high)$")
    home_lat: float = Field(ge=-90, le=90)
    home_lon: float = Field(ge=-180, le=180)


class ProfileResponse(ProfileCreateRequest):
    id: str
    user_id: str

    @staticmethod
    def create(user_id: str, payload: ProfileCreateRequest) -> "ProfileResponse":
        return ProfileResponse(
            id=str(uuid4()),
            user_id=user_id,
            persona_type=payload.persona_type,
            sensitivity_level=payload.sensitivity_level,
            home_lat=payload.home_lat,
            home_lon=payload.home_lon,
        )
