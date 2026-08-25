"""Family member links — Postgres when available, in-memory fallback for tests/dev."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from psycopg import OperationalError
from psycopg.errors import UndefinedTable

from app.models.family import FamilyMemberCreateRequest, FamilyMemberLink, FamilyRelation
from app.services.db import get_connection

_STORE: dict[str, dict[str, FamilyMemberLink]] = {}
_FORCE_MEMORY = False


def reset_store() -> None:
    """Clear in-memory family links — test helper only."""
    _STORE.clear()


def force_memory_store(enabled: bool = True) -> None:
    """Force in-memory mode (unit tests)."""
    global _FORCE_MEMORY
    _FORCE_MEMORY = enabled


def _row_to_link(row: dict) -> FamilyMemberLink:
    created = row.get("created_at")
    return FamilyMemberLink(
        id=str(row["id"]),
        ownerUserId=str(row["user_id"]),
        memberProfileId=str(row["member_profile_id"]),
        relation=FamilyRelation(row["relation"]),
        label=row.get("label"),
        createdAt=created.isoformat() if hasattr(created, "isoformat") else created,
    )


def _create_memory(*, owner_user_id: str, payload: FamilyMemberCreateRequest) -> FamilyMemberLink:
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


def _list_memory(*, owner_user_id: str) -> list[FamilyMemberLink]:
    bucket = _STORE.get(owner_user_id, {})
    return sorted(bucket.values(), key=lambda item: item.createdAt or "")


def _delete_memory(*, owner_user_id: str, member_link_id: str) -> bool:
    bucket = _STORE.get(owner_user_id)
    if not bucket or member_link_id not in bucket:
        return False
    del bucket[member_link_id]
    if not bucket:
        _STORE.pop(owner_user_id, None)
    return True


def create_member(*, owner_user_id: str, payload: FamilyMemberCreateRequest) -> FamilyMemberLink:
    if _FORCE_MEMORY:
        return _create_memory(owner_user_id=owner_user_id, payload=payload)
    link_id = str(uuid4())
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO family_member_links (id, user_id, member_profile_id, relation, label)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING id, user_id, member_profile_id, relation, label, created_at
                    """,
                    (
                        link_id,
                        owner_user_id,
                        payload.memberProfileId,
                        payload.relation.value,
                        payload.label,
                    ),
                )
                row = cur.fetchone()
                return _row_to_link(dict(row))
    except (UndefinedTable, OperationalError):
        return _create_memory(owner_user_id=owner_user_id, payload=payload)


def list_members(*, owner_user_id: str) -> list[FamilyMemberLink]:
    if _FORCE_MEMORY:
        return _list_memory(owner_user_id=owner_user_id)
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, user_id, member_profile_id, relation, label, created_at
                    FROM family_member_links
                    WHERE user_id = %s
                    ORDER BY created_at ASC
                    """,
                    (owner_user_id,),
                )
                rows = cur.fetchall() or []
                return [_row_to_link(dict(row)) for row in rows]
    except (UndefinedTable, OperationalError):
        return _list_memory(owner_user_id=owner_user_id)


def delete_member(*, owner_user_id: str, member_link_id: str) -> bool:
    if _FORCE_MEMORY:
        return _delete_memory(owner_user_id=owner_user_id, member_link_id=member_link_id)
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    DELETE FROM family_member_links
                    WHERE user_id = %s AND id = %s
                    """,
                    (owner_user_id, member_link_id),
                )
                if cur.rowcount > 0:
                    return True
                return False
    except (UndefinedTable, OperationalError):
        return _delete_memory(owner_user_id=owner_user_id, member_link_id=member_link_id)
