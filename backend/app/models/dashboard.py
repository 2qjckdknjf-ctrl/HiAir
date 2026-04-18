from pydantic import BaseModel

from app.models.risk import EnvironmentSnapshot


class DashboardOverviewResponse(BaseModel):
    profile_id: str | None
    environment: EnvironmentSnapshot
    risk_score: int
    risk_level: str
    recommendations: list[str]
    daily_summary: str
    daily_actions: list[str]
    should_notify: bool
    notification_text: str
