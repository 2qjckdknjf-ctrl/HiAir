from app.core.settings import settings
from app.services.db import get_connection


def is_supabase_profile_ownership_mode() -> bool:
    return settings.hiair_auth_provider == "supabase" and bool(settings.supabase_url.strip())


def profile_owner_user_id(profile_id: str) -> str | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT user_id FROM profiles WHERE id = %s",
                (profile_id,),
            )
            row = cur.fetchone()
    if row is None or row["user_id"] is None:
        return None
    return str(row["user_id"])


def profile_exists(profile_id: str) -> bool:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT 1 FROM profiles WHERE id = %s LIMIT 1",
                (profile_id,),
            )
            row = cur.fetchone()
    return row is not None


def profile_belongs_to_user(profile_id: str, user_id: str) -> bool:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1
                FROM profiles
                WHERE id = %s
                  AND user_id = %s
                LIMIT 1
                """,
                (profile_id, user_id),
            )
            row = cur.fetchone()
    return row is not None
