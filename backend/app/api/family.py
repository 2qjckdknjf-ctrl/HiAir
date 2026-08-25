"""HiAir 1.5 family caregiver API (stub — additive)."""

from fastapi import APIRouter, Depends, HTTPException, Response, status

from app.api.deps import get_current_user_id
from app.models.family import (
    FamilyMemberCreateRequest,
    FamilyMemberLink,
    FamilyMemberListResponse,
    FamilyRiskOverviewResponse,
)
import app.services.air_repository as air_repository
import app.services.family_repository as family_repository
import app.services.family_risk_service as family_risk_service

router = APIRouter(prefix="/family", tags=["family"])


@router.get("/members", response_model=FamilyMemberListResponse)
def list_family_members(
    user_id: str = Depends(get_current_user_id),
) -> FamilyMemberListResponse:
    return FamilyMemberListResponse(members=family_repository.list_members(owner_user_id=user_id))


@router.post("/members", response_model=FamilyMemberLink)
def create_family_member(
    payload: FamilyMemberCreateRequest,
    user_id: str = Depends(get_current_user_id),
) -> FamilyMemberLink:
    profile = air_repository.get_profile_context(payload.memberProfileId)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.user_id != user_id:
        raise HTTPException(status_code=403, detail="Profile does not belong to user")
    return family_repository.create_member(owner_user_id=user_id, payload=payload)


@router.delete("/members/{memberLinkId}", status_code=status.HTTP_204_NO_CONTENT)
def delete_family_member(
    memberLinkId: str,
    user_id: str = Depends(get_current_user_id),
) -> Response:
    deleted = family_repository.delete_member(owner_user_id=user_id, member_link_id=memberLinkId)
    if not deleted:
        raise HTTPException(status_code=404, detail="Family member link not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/risk-overview", response_model=FamilyRiskOverviewResponse)
def get_family_risk_overview(
    user_id: str = Depends(get_current_user_id),
) -> FamilyRiskOverviewResponse:
    return family_risk_service.build_family_risk_overview(owner_user_id=user_id)
