"""In-memory family member links (HiAir 1.5 caregiver stub)."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from app.models.family import FamilyMemberCreateRequest, FamilyMemberLink

_STORE: dict[str, dict[str, FamilyMemberLink]] = {}


def reset_store() -> None:
    _STORE.clear()


def create_member(*, owner_user_id: str, payload: FamilyMemberCreateRequest) -> FamilyMemberLink:
    link = FamilyMemberLink(
        id=str(uuid4()),
        ownerUserId=owner_user_id,
        memberProfileId=payload.memberProfileId,
        relation=payload.relation,
        label=payload.label,
        createdAt=datetime.now(tz=UTC).isoformat(),
    )
    bucket = _STORE.setdefault(owner_user_id, {})
    bucket[link.id] = link
    return link


def list_members(*, owner_user_id: str) -> list[FamilyMemberLink]:
    bucket = _STORE.get(owner_user_id, {})
    return sorted(bucket.values(), key=lambda item: item.createdAt or "")


def delete_member(*, owner_user_id: str, member_link_id: str) -> bool:
    bucket = _STORE.get(owner_user_id)
    if not bucket or member_link_id not in bucket:
        return False
    del bucket[member_link_id]
    if not bucket:
        _STORE.pop(owner_user_id, None)
    return True
