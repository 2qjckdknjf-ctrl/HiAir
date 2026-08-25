from fastapi import APIRouter, Depends, HTTPException
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
import app.services.entitlement_service as entitlement_service
from app.models.briefing import BriefingScheduleResponse, BriefingScheduleUpdateRequest
import app.services.air_repository as air_repository
import app.services.briefing_repository as briefing_repository
import app.services.travel_location as travel_location

router = APIRouter(prefix="/briefings", tags=["briefings"])


@router.get("/schedule", response_model=BriefingScheduleResponse)
def get_schedule(user_id: str = Depends(get_current_user_id)) -> BriefingScheduleResponse:
    try:
        timezone = _resolve_timezone(user_id)
        return briefing_repository.get_schedule(user_id=user_id, timezone=timezone)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.put("/schedule", response_model=BriefingScheduleResponse)
def put_schedule(
    payload: BriefingScheduleUpdateRequest,
    user_id: str = Depends(get_current_user_id),
) -> BriefingScheduleResponse:
    try:
        entitlement_service.require_feature(user_id, "custom_alerts", "custom_alerts_enabled")
        timezone = _resolve_timezone(user_id)
        return briefing_repository.upsert_schedule(user_id=user_id, payload=payload, timezone=timezone)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


def _resolve_timezone(user_id: str) -> str:
    profile_ids = briefing_repository.get_user_profile_ids(user_id)
    if not profile_ids:
        return "UTC"
    profile = air_repository.get_profile_context(profile_ids[0])
    if profile is None:
        return "UTC"
    profile = travel_location.apply_travel_location_override(user_id, profile)
    return profile.timezone or "UTC"
