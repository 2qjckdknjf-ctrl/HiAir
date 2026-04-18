from fastapi import APIRouter, Depends, HTTPException
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.settings import UserSettingsResponse, UserSettingsUpdateRequest
import app.services.settings_repository as settings_repository

router = APIRouter(prefix="/settings", tags=["settings"])

@router.get("", response_model=UserSettingsResponse)
def get_settings(user_id: str = Depends(get_current_user_id)) -> UserSettingsResponse:
    try:
        return settings_repository.get_user_settings(user_id=user_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.put("", response_model=UserSettingsResponse)
def update_settings(
    payload: UserSettingsUpdateRequest,
    user_id: str = Depends(get_current_user_id),
) -> UserSettingsResponse:
    try:
        return settings_repository.upsert_user_settings(user_id=user_id, payload=payload)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
