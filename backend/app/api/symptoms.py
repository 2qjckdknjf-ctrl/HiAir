from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.air import SymptomCreateRequest, SymptomHistoryItem, SymptomHistoryResponse
from app.models.risk import SymptomLogCreateRequest, SymptomLogResponse
import app.services.air_repository as air_repository
import app.services.profile_access as profile_access
import app.services.risk_repository as risk_repository

router = APIRouter(prefix="/symptoms", tags=["symptoms"])


@router.post("/log", response_model=SymptomLogResponse)
def create_symptom_log(
    payload: SymptomLogCreateRequest,
    user_id: str = Depends(get_current_user_id),
) -> SymptomLogResponse:
    try:
        if not profile_access.profile_exists(payload.profile_id):
            raise HTTPException(status_code=404, detail="Profile not found")
        if not profile_access.profile_belongs_to_user(payload.profile_id, user_id):
            raise HTTPException(status_code=403, detail="Profile does not belong to user")
        created = risk_repository.create_symptom_log(
            profile_id=payload.profile_id,
            symptom=payload.symptom,
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return SymptomLogResponse(
        id=created["id"],
        profile_id=created["profile_id"],
        timestamp_utc=created["timestamp_utc"],
        symptom=payload.symptom,
    )


@router.post("", response_model=SymptomHistoryItem)
def create_quick_symptom(
    payload: SymptomCreateRequest,
    user_id: str = Depends(get_current_user_id),
) -> SymptomHistoryItem:
    try:
        if not profile_access.profile_exists(payload.profileId):
            raise HTTPException(status_code=404, detail="Profile not found")
        if not profile_access.profile_belongs_to_user(payload.profileId, user_id):
            raise HTTPException(status_code=403, detail="Profile does not belong to user")
        item = air_repository.create_symptom_entry(
            profile_id=payload.profileId,
            symptom_type=payload.symptomType,
            intensity=payload.intensity,
            note=payload.note,
        )
        return item
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.get("/history", response_model=SymptomHistoryResponse)
def get_symptom_history(
    profileId: str = Query(...),
    user_id: str = Depends(get_current_user_id),
) -> SymptomHistoryResponse:
    try:
        if not profile_access.profile_exists(profileId):
            raise HTTPException(status_code=404, detail="Profile not found")
        if not profile_access.profile_belongs_to_user(profileId, user_id):
            raise HTTPException(status_code=403, detail="Profile does not belong to user")
        items = air_repository.get_symptom_history(profile_id=profileId)
        return SymptomHistoryResponse(profileId=profileId, items=items)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
