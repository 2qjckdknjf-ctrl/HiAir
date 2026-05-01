from pydantic import BaseModel, Field


class BriefingScheduleResponse(BaseModel):
    user_id: str
    local_time: str
    timezone: str
    enabled: bool
    last_sent_at: str | None = None


class BriefingScheduleUpdateRequest(BaseModel):
    local_time: str = Field(default="07:30", pattern=r"^\d{2}:\d{2}$")
    enabled: bool
