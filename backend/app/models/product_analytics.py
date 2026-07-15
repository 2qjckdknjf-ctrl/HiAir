from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class AnalyticsEventName(str, Enum):
    ONBOARDING_STARTED = "onboarding_started"
    ONBOARDING_COMPLETED = "onboarding_completed"
    DASHBOARD_OPENED = "dashboard_opened"
    MORNING_BRIEFING_OPENED = "morning_briefing_opened"
    SHARE_CARD_CLICKED = "share_card_clicked"
    SYMPTOM_LOGGED = "symptom_logged"
    PRIVACY_EXPORT_REQUESTED = "privacy_export_requested"
    PRIVACY_DELETE_REQUESTED = "privacy_delete_requested"
    GUEST_MODE_USED = "guest_mode_used"
    FEEDBACK_SUBMITTED = "feedback_submitted"
    APP_INSTALL_TRACKED = "app_install_tracked"


class AnalyticsEventCreate(BaseModel):
    session_id: str = Field(min_length=1, max_length=128)
    event_name: AnalyticsEventName
    properties: dict[str, str | int | float | bool | None] = Field(default_factory=dict)
    platform: str = Field(default="unknown", max_length=32)
    app_version: str | None = Field(default=None, max_length=32)


class AnalyticsEventsBatchRequest(BaseModel):
    events: list[AnalyticsEventCreate] = Field(min_length=1, max_length=50)


class AnalyticsEventResponse(BaseModel):
    id: str
    event_name: str
    created_at: datetime


class AnalyticsEventsBatchResponse(BaseModel):
    accepted: int


class KpiDashboardResponse(BaseModel):
    window_days: int
    installs_tracked: int
    onboarding_started: int
    onboarding_completed: int
    onboarding_completion_rate_pct: float
    d1_retention_pct: float
    dashboard_opens: int
    morning_briefing_opens: int
    symptom_logs: int
    share_clicks: int
    guest_mode_uses: int
    feedback_submissions: int
    crash_reports: int


class FeedbackSubmitRequest(BaseModel):
    liked: str = Field(default="", max_length=4000)
    confusing: str = Field(default="", max_length=4000)
    broken: str = Field(default="", max_length=4000)
    contact_email: str | None = Field(default=None, max_length=320)
    platform: str = Field(default="unknown", max_length=32)
    app_version: str | None = Field(default=None, max_length=32)


class FeedbackSubmitResponse(BaseModel):
    id: str
    created_at: datetime


class CrashReportRequest(BaseModel):
    session_id: str | None = Field(default=None, max_length=128)
    message: str = Field(min_length=1, max_length=2000)
    stack_trace: str | None = Field(default=None, max_length=20000)
    platform: str = Field(default="unknown", max_length=32)
    app_version: str | None = Field(default=None, max_length=32)


class CrashReportResponse(BaseModel):
    id: str
    created_at: datetime
