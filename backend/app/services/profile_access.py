from app.services.db import get_connection


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
