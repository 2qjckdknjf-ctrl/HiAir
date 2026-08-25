"""Travel mode API — temporary location override via saved place (HiAir 1.5)."""

from fastapi import APIRouter, Depends, HTTPException
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.travel import TravelSession, TravelSessionStartRequest, parse_until
import app.services.travel_repository as travel_repository

router = APIRouter(prefix="/travel", tags=["travel"])


@router.get("/session", response_model=TravelSession)
def get_travel_session(user_id: str = Depends(get_current_user_id)) -> TravelSession:
    try:
        return travel_repository.get_travel_session(user_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.post("/session", response_model=TravelSession)
def start_travel_session(
    payload: TravelSessionStartRequest,
    user_id: str = Depends(get_current_user_id),
) -> TravelSession:
    try:
        until = parse_until(payload.until)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail="Invalid until timestamp") from exc
    try:
        return travel_repository.start_travel_session(
            user_id,
            place_id=payload.placeId,
            until=until,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.delete("/session", response_model=TravelSession)
def clear_travel_session(user_id: str = Depends(get_current_user_id)) -> TravelSession:
    try:
        return travel_repository.clear_travel_session(user_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
