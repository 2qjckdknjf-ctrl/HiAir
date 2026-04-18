from pydantic import BaseModel, Field


class UserSettingsResponse(BaseModel):
    user_id: str
    push_alerts_enabled: bool
    alert_threshold: str
    default_persona: str
    quiet_hours_start: int
    quiet_hours_end: int
    profile_based_alerting: bool
    preferred_language: str


class UserSettingsUpdateRequest(BaseModel):
    push_alerts_enabled: bool
    alert_threshold: str = Field(pattern="^(medium|high|very_high)$")
    default_persona: str = Field(pattern="^(adult|child|elderly|asthma|allergy|runner|worker)$")
    quiet_hours_start: int = Field(default=22, ge=0, le=23)
    quiet_hours_end: int = Field(default=7, ge=0, le=23)
    profile_based_alerting: bool = True
    preferred_language: str = Field(default="ru", pattern="^(ru|en)$")
