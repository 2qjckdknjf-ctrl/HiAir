"""HiAir 1.5 Family / caregiver monitoring stubs (additive)."""

from enum import Enum

from pydantic import BaseModel, Field


class FamilyRelation(str, Enum):
    CHILD = "child"
    PARENT = "parent"
    ELDERLY = "elderly"
    PARTNER = "partner"
    OTHER = "other"


class FamilyMemberLink(BaseModel):
    id: str
    ownerUserId: str
    memberProfileId: str
    relation: FamilyRelation
    label: str | None = None
    createdAt: str | None = None


class FamilyMemberCreateRequest(BaseModel):
    memberProfileId: str = Field(min_length=1)
    relation: FamilyRelation
    label: str | None = Field(default=None, max_length=80)


class FamilyMemberListResponse(BaseModel):
    members: list[FamilyMemberLink] = Field(default_factory=list)


class FamilyMemberRiskLine(BaseModel):
    memberLinkId: str
    memberProfileId: str
    relation: FamilyRelation
    label: str | None = None
    riskLevel: str
    riskScore: int = Field(ge=0, le=100)
    available: bool = True
    unavailableReason: str | None = None


class FamilyRiskOverviewResponse(BaseModel):
    ownerUserId: str
    assessedAt: str
    members: list[FamilyMemberRiskLine] = Field(default_factory=list)
    highestRiskLevel: str | None = None
