from uuid import uuid4

from app.models.user import (
    ProfileCreateRequest,
    ProfileResponse,
    ProfileUpdateRequest,
    _age_years_from_dob,
    age_group_from_date_of_birth,
)
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


def _row_to_profile(row: dict) -> ProfileResponse:
    dob = row.get("date_of_birth")
    return ProfileResponse(
        id=str(row["id"]),
        user_id=str(row["user_id"]),
        persona_type=row["persona_type"],
        sensitivity_level=row["sensitivity_level"],
        home_lat=row["home_lat"],
        home_lon=row["home_lon"],
        date_of_birth=dob,
        age_years=_age_years_from_dob(dob),
    )


def create_profile(user_id: str, payload: ProfileCreateRequest) -> ProfileResponse:
    profile_id = str(uuid4())
    age_group = age_group_from_date_of_birth(payload.date_of_birth, payload.persona_type.value)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO profiles (
                    id, user_id, persona_type, sensitivity_level, home_lat, home_lon,
                    date_of_birth, age_group
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    profile_id,
                    user_id,
                    payload.persona_type.value,
                    payload.sensitivity_level,
                    payload.home_lat,
                    payload.home_lon,
                    payload.date_of_birth,
                    age_group,
                ),
            )
    return ProfileResponse(
        id=profile_id,
        user_id=user_id,
        persona_type=payload.persona_type,
        sensitivity_level=payload.sensitivity_level,
        home_lat=payload.home_lat,
        home_lon=payload.home_lon,
        date_of_birth=payload.date_of_birth,
        age_years=_age_years_from_dob(payload.date_of_birth),
    )


def update_profile(user_id: str, profile_id: str, payload: ProfileUpdateRequest) -> ProfileResponse | None:
    existing = get_profile(user_id=user_id, profile_id=profile_id)
    if existing is None:
        return None
    persona_type = payload.persona_type or existing.persona_type
    persona_value = persona_type.value if hasattr(persona_type, "value") else str(persona_type)
    sensitivity_level = payload.sensitivity_level or existing.sensitivity_level
    home_lat = payload.home_lat if payload.home_lat is not None else existing.home_lat
    home_lon = payload.home_lon if payload.home_lon is not None else existing.home_lon
    date_of_birth = payload.date_of_birth if payload.date_of_birth is not None else existing.date_of_birth
    age_group = age_group_from_date_of_birth(date_of_birth, persona_value)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE profiles
                SET persona_type = %s,
                    sensitivity_level = %s,
                    home_lat = %s,
                    home_lon = %s,
                    date_of_birth = %s,
                    age_group = %s,
                    updated_at = NOW()
                WHERE id = %s AND user_id = %s
                """,
                (
                    persona_value,
                    sensitivity_level,
                    home_lat,
                    home_lon,
                    date_of_birth,
                    age_group,
                    profile_id,
                    user_id,
                ),
            )
    return get_profile(user_id=user_id, profile_id=profile_id)


def get_profile(user_id: str, profile_id: str) -> ProfileResponse | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, user_id, persona_type, sensitivity_level, home_lat, home_lon, date_of_birth
                FROM profiles
                WHERE id = %s AND user_id = %s
                LIMIT 1
                """,
                (profile_id, user_id),
            )
            row = cur.fetchone()
    if row is None:
        return None
    return _row_to_profile(row)


def list_profiles(user_id: str) -> list[ProfileResponse]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, user_id, persona_type, sensitivity_level, home_lat, home_lon, date_of_birth
                FROM profiles
                WHERE user_id = %s
                ORDER BY created_at DESC
                """,
                (user_id,),
            )
            rows = cur.fetchall()
    return [_row_to_profile(row) for row in rows]
