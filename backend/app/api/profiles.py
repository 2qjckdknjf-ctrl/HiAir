from fastapi import APIRouter, Depends, HTTPException
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.user import ProfileCreateRequest, ProfileResponse
import app.services.user_repository as user_repository

router = APIRouter(prefix="/profiles", tags=["profiles"])


@router.post("", response_model=ProfileResponse)
def create_profile(
    payload: ProfileCreateRequest,
    user_id: str = Depends(get_current_user_id),
) -> ProfileResponse:
    try:
        return user_repository.create_profile(user_id=user_id, payload=payload)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.get("", response_model=list[ProfileResponse])
def list_profiles(user_id: str = Depends(get_current_user_id)) -> list[ProfileResponse]:
    try:
        return user_repository.list_profiles(user_id=user_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
