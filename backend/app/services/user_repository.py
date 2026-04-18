from uuid import uuid4

from app.models.user import ProfileCreateRequest, ProfileResponse
from app.services.db import get_connection
from app.services.security import hash_password, verify_password


class UserConflictError(ValueError):
    pass


class AuthError(ValueError):
    pass


def create_user(email: str, password: str) -> str:
    user_id = str(uuid4())
    password_hash = hash_password(password)
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO users (id, email, password_hash)
                    VALUES (%s, %s, %s)
                    """,
                    (user_id, email, password_hash),
                )
    except Exception as exc:
        if "duplicate key" in str(exc).lower():
            raise UserConflictError("User already exists") from exc
        raise
    return user_id


def verify_user(email: str, password: str) -> str:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, password_hash FROM users WHERE email = %s",
                (email,),
            )
            row = cur.fetchone()
    if row is None:
        raise AuthError("Invalid credentials")
    if not verify_password(password, row["password_hash"]):
        raise AuthError("Invalid credentials")
    return str(row["id"])


def user_exists(user_id: str) -> bool:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM users WHERE id = %s LIMIT 1", (user_id,))
            row = cur.fetchone()
    return row is not None


def create_profile(user_id: str, payload: ProfileCreateRequest) -> ProfileResponse:
    profile_id = str(uuid4())
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO profiles (id, user_id, persona_type, sensitivity_level, home_lat, home_lon)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    profile_id,
                    user_id,
                    payload.persona_type.value,
                    payload.sensitivity_level,
                    payload.home_lat,
                    payload.home_lon,
                ),
            )
    return ProfileResponse(
        id=profile_id,
        user_id=user_id,
        persona_type=payload.persona_type,
        sensitivity_level=payload.sensitivity_level,
        home_lat=payload.home_lat,
        home_lon=payload.home_lon,
    )


def list_profiles(user_id: str) -> list[ProfileResponse]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, user_id, persona_type, sensitivity_level, home_lat, home_lon
                FROM profiles
                WHERE user_id = %s
                ORDER BY created_at DESC
                """,
                (user_id,),
            )
            rows = cur.fetchall()
    return [
        ProfileResponse(
            id=str(row["id"]),
            user_id=str(row["user_id"]),
            persona_type=row["persona_type"],
            sensitivity_level=row["sensitivity_level"],
            home_lat=row["home_lat"],
            home_lon=row["home_lon"],
        )
        for row in rows
    ]
