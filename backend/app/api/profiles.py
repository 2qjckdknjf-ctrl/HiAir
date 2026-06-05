from fastapi import APIRouter, Depends, HTTPException
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.user import ProfileCreateRequest, ProfileResponse, ProfileUpdateRequest
import app.services.entitlement_service as entitlement_service
import app.services.user_repository as user_repository

router = APIRouter(prefix="/profiles", tags=["profiles"])


@router.post("", response_model=ProfileResponse)
def create_profile(
    payload: ProfileCreateRequest,
    user_id: str = Depends(get_current_user_id),
) -> ProfileResponse:
    try:
        entitlement_service.assert_profile_limit(user_id)
        return user_repository.create_profile(user_id=user_id, payload=payload)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.get("", response_model=list[ProfileResponse])
def list_profiles(user_id: str = Depends(get_current_user_id)) -> list[ProfileResponse]:
    try:
        return user_repository.list_profiles(user_id=user_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.patch("/{profile_id}", response_model=ProfileResponse)
def update_profile(
    profile_id: str,
    payload: ProfileUpdateRequest,
    user_id: str = Depends(get_current_user_id),
) -> ProfileResponse:
    try:
        updated = user_repository.update_profile(
            user_id=user_id,
            profile_id=profile_id,
            payload=payload,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    if updated is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    return updated
