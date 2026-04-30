from __future__ import annotations

from app.models.briefing import BriefingScheduleResponse, BriefingScheduleUpdateRequest
from app.services.db import get_connection


def get_schedule(user_id: str, timezone: str = "UTC") -> BriefingScheduleResponse:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT user_id, local_time, timezone, enabled, last_sent_at
                FROM briefing_schedule
                WHERE user_id = %s
                """,
                (user_id,),
            )
            row = cur.fetchone()
    if row is None:
        return BriefingScheduleResponse(
            user_id=user_id,
            local_time="07:30",
            timezone=timezone,
            enabled=False,
            last_sent_at=None,
        )
    return BriefingScheduleResponse(
        user_id=str(row["user_id"]),
        local_time=str(row["local_time"])[:5],
        timezone=row["timezone"] or timezone,
        enabled=bool(row["enabled"]),
        last_sent_at=row["last_sent_at"].isoformat() if row["last_sent_at"] else None,
    )


def upsert_schedule(user_id: str, payload: BriefingScheduleUpdateRequest, timezone: str) -> BriefingScheduleResponse:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO briefing_schedule (user_id, local_time, timezone, enabled, updated_at)
                VALUES (%s, %s::time, %s, %s, NOW())
                ON CONFLICT (user_id)
                DO UPDATE SET
                    local_time = EXCLUDED.local_time,
                    timezone = EXCLUDED.timezone,
                    enabled = EXCLUDED.enabled,
                    updated_at = NOW()
                RETURNING user_id, local_time, timezone, enabled, last_sent_at
                """,
                (user_id, payload.local_time, timezone, payload.enabled),
            )
            row = cur.fetchone()
    return BriefingScheduleResponse(
        user_id=str(row["user_id"]),
        local_time=str(row["local_time"])[:5],
        timezone=row["timezone"] or timezone,
        enabled=bool(row["enabled"]),
        last_sent_at=row["last_sent_at"].isoformat() if row["last_sent_at"] else None,
    )


def list_enabled_schedules() -> list[dict[str, str | bool | None]]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT user_id, local_time, timezone, enabled, last_sent_at
                FROM briefing_schedule
                WHERE enabled = TRUE
                ORDER BY local_time ASC
                """
            )
            rows = cur.fetchall()
    return [
        {
            "user_id": str(row["user_id"]),
            "local_time": str(row["local_time"])[:5],
            "timezone": row["timezone"] or "UTC",
            "enabled": bool(row["enabled"]),
            "last_sent_at": row["last_sent_at"].isoformat() if row["last_sent_at"] else None,
        }
        for row in rows
    ]


def mark_sent(user_id: str) -> None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE briefing_schedule
                SET last_sent_at = NOW(), updated_at = NOW()
                WHERE user_id = %s
                """,
                (user_id,),
            )


def get_user_profile_ids(user_id: str) -> list[str]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id
                FROM profiles
                WHERE user_id = %s
                ORDER BY created_at ASC
                """,
                (user_id,),
            )
            rows = cur.fetchall()
    return [str(row["id"]) for row in rows]
