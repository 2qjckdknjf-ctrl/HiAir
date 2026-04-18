from uuid import uuid4

from app.services.db import get_connection


def save_notification_event(
    profile_id: str | None,
    risk_level: str,
    should_send: bool,
    message: str,
) -> str:
    event_id = str(uuid4())
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO notification_events (id, profile_id, risk_level, should_send, message)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (event_id, profile_id, risk_level, should_send, message),
            )
    return event_id


def resolve_user_id_by_profile(profile_id: str) -> str | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT user_id FROM profiles WHERE id = %s", (profile_id,))
            row = cur.fetchone()
    if row is None:
        return None
    return str(row["user_id"])


def upsert_device_token(
    user_id: str,
    platform: str,
    device_token: str,
    profile_id: str | None = None,
) -> dict[str, str | bool | None]:
    token_id = str(uuid4())
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO push_device_tokens
                (id, user_id, profile_id, platform, device_token, is_active, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, TRUE, NOW(), NOW())
                ON CONFLICT (platform, device_token)
                DO UPDATE SET
                    user_id = EXCLUDED.user_id,
                    profile_id = EXCLUDED.profile_id,
                    is_active = TRUE,
                    updated_at = NOW()
                RETURNING id, user_id, profile_id, platform, device_token, is_active
                """,
                (token_id, user_id, profile_id, platform, device_token),
            )
            row = cur.fetchone()
    return {
        "id": str(row["id"]),
        "user_id": str(row["user_id"]),
        "profile_id": str(row["profile_id"]) if row["profile_id"] else None,
        "platform": row["platform"],
        "device_token": row["device_token"],
        "is_active": bool(row["is_active"]),
    }


def list_active_device_tokens(user_id: str) -> list[str]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT device_token
                FROM push_device_tokens
                WHERE user_id = %s AND is_active = TRUE
                """,
                (user_id,),
            )
            rows = cur.fetchall()
    return [row["device_token"] for row in rows]


def list_active_device_targets(user_id: str) -> list[dict[str, str]]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT platform, device_token
                FROM push_device_tokens
                WHERE user_id = %s AND is_active = TRUE
                """,
                (user_id,),
            )
            rows = cur.fetchall()
    return [{"platform": row["platform"], "device_token": row["device_token"]} for row in rows]


def save_delivery_attempt(
    event_id: str,
    user_id: str | None,
    platform: str,
    device_token: str,
    provider_mode: str,
    attempt_no: int,
    success: bool,
    reason: str,
    status_code: int | None = None,
) -> str:
    attempt_id = str(uuid4())
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO notification_delivery_attempts
                (id, event_id, user_id, platform, device_token, provider_mode, attempt_no, success, status_code, reason)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    attempt_id,
                    event_id,
                    user_id,
                    platform,
                    device_token,
                    provider_mode,
                    attempt_no,
                    success,
                    status_code,
                    reason,
                ),
            )
    return attempt_id


def update_notification_event_status(event_id: str, should_send: bool) -> None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE notification_events
                SET should_send = %s
                WHERE id = %s
                """,
                (should_send, event_id),
            )


def save_secret_rotation_event(
    provider: str,
    key_ref: str | None = None,
    rotated_by: str | None = None,
    notes: str | None = None,
) -> dict[str, str]:
    event_id = str(uuid4())
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO notification_secret_rotation_events
                (id, provider, key_ref, rotated_by, notes)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id, provider, created_at
                """,
                (event_id, provider, key_ref, rotated_by, notes),
            )
            row = cur.fetchone()
    return {
        "id": str(row["id"]),
        "provider": row["provider"],
        "created_at": row["created_at"].isoformat(),
    }


def get_latest_secret_rotation_event(provider: str) -> dict[str, str] | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, provider, key_ref, rotated_by, notes, created_at
                FROM notification_secret_rotation_events
                WHERE provider = %s
                ORDER BY created_at DESC
                LIMIT 1
                """,
                (provider,),
            )
            row = cur.fetchone()
    if row is None:
        return None
    return {
        "id": str(row["id"]),
        "provider": row["provider"],
        "key_ref": row["key_ref"] or "",
        "rotated_by": row["rotated_by"] or "",
        "notes": row["notes"] or "",
        "created_at": row["created_at"].isoformat(),
    }


def list_delivery_attempts(
    user_id: str | None = None,
    profile_id: str | None = None,
    limit: int = 100,
) -> list[dict[str, str | int | bool | None]]:
    where_clauses: list[str] = []
    params: list[str | int] = []
    if user_id:
        where_clauses.append("nda.user_id = %s")
        params.append(user_id)
    if profile_id:
        where_clauses.append("ne.profile_id = %s")
        params.append(profile_id)

    where_sql = ""
    if where_clauses:
        where_sql = "WHERE " + " AND ".join(where_clauses)

    query = f"""
        SELECT
            nda.id,
            nda.event_id,
            nda.user_id,
            ne.profile_id,
            nda.platform,
            nda.provider_mode,
            nda.attempt_no,
            nda.success,
            nda.status_code,
            nda.reason,
            nda.created_at
        FROM notification_delivery_attempts nda
        LEFT JOIN notification_events ne ON ne.id = nda.event_id
        {where_sql}
        ORDER BY nda.created_at DESC
        LIMIT %s
    """
    params.append(limit)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, tuple(params))
            rows = cur.fetchall()

    return [
        {
            "id": str(row["id"]),
            "event_id": str(row["event_id"]),
            "user_id": str(row["user_id"]) if row["user_id"] else None,
            "profile_id": str(row["profile_id"]) if row["profile_id"] else None,
            "platform": row["platform"],
            "provider_mode": row["provider_mode"],
            "attempt_no": int(row["attempt_no"]),
            "success": bool(row["success"]),
            "status_code": int(row["status_code"]) if row["status_code"] is not None else None,
            "reason": row["reason"],
            "created_at": row["created_at"].isoformat(),
        }
        for row in rows
    ]
