from datetime import datetime
from typing import Any

from pydantic import BaseModel


class PrivacyExportResponse(BaseModel):
    user_id: str
    exported_at: datetime
    data: dict[str, Any]


class DeleteAccountRequest(BaseModel):
    confirmation: str


class DeleteAccountResponse(BaseModel):
    deleted: bool
