from pydantic import BaseModel


class DailyRecommendationResponse(BaseModel):
    profile_id: str
    risk_level: str
    summary: str
    actions: list[str]
