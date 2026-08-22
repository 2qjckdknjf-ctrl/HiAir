from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field


class PrivacyExportResponse(BaseModel):
    user_id: str
    exported_at: datetime
    data: dict[str, Any]


class DeleteAccountRequest(BaseModel):
    confirmation: str
    apple_authorization_code: str | None = None


class DeleteAccountResponse(BaseModel):
    deleted: bool
    operation_id: str | None = None
    stages: dict[str, Literal["pending", "completed", "failed", "not_applicable"]] = Field(
        default_factory=dict
    )
    recovery_hint: str | None = None
