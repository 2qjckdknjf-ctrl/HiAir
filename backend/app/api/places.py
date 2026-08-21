from fastapi import APIRouter, Depends, HTTPException

from app.api.deps import get_current_user_id
from app.models.places import SavedPlace, SavedPlaceCreateRequest, SavedPlaceListResponse
import app.services.places_repository as places_repository

router = APIRouter(prefix="/places", tags=["places"])


@router.get("", response_model=SavedPlaceListResponse)
def list_saved_places(user_id: str = Depends(get_current_user_id)) -> SavedPlaceListResponse:
    places = places_repository.list_places(user_id=user_id)
    return SavedPlaceListResponse(places=places)


@router.post("", response_model=SavedPlace)
def create_saved_place(
    payload: SavedPlaceCreateRequest,
    user_id: str = Depends(get_current_user_id),
) -> SavedPlace:
    try:
        return places_repository.create_place(user_id=user_id, payload=payload)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.delete("/{place_id}", status_code=204)
def delete_saved_place(
    place_id: str,
    user_id: str = Depends(get_current_user_id),
) -> None:
    deleted = places_repository.delete_place(user_id=user_id, place_id=place_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Place not found")
