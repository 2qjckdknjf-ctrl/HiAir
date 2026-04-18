from app.models.settings import UserSettingsResponse, UserSettingsUpdateRequest
from app.services.db import get_connection


def get_user_settings(user_id: str) -> UserSettingsResponse:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    user_id,
                    push_alerts_enabled,
                    alert_threshold,
                    default_persona,
                    quiet_hours_start,
                    quiet_hours_end,
                    profile_based_alerting,
                    preferred_language
                FROM user_settings
                WHERE user_id = %s
                """,
                (user_id,),
            )
            row = cur.fetchone()

    if row is None:
        return UserSettingsResponse(
            user_id=user_id,
            push_alerts_enabled=True,
            alert_threshold="high",
            default_persona="adult",
            quiet_hours_start=22,
            quiet_hours_end=7,
            profile_based_alerting=True,
            preferred_language="ru",
        )

    return UserSettingsResponse(
        user_id=str(row["user_id"]),
        push_alerts_enabled=bool(row["push_alerts_enabled"]),
        alert_threshold=row["alert_threshold"],
        default_persona=row["default_persona"],
        quiet_hours_start=int(row["quiet_hours_start"]),
        quiet_hours_end=int(row["quiet_hours_end"]),
        profile_based_alerting=bool(row["profile_based_alerting"]),
        preferred_language=row["preferred_language"] or "ru",
    )


def upsert_user_settings(user_id: str, payload: UserSettingsUpdateRequest) -> UserSettingsResponse:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO user_settings (
                    user_id,
                    push_alerts_enabled,
                    alert_threshold,
                    default_persona,
                    quiet_hours_start,
                    quiet_hours_end,
                    profile_based_alerting,
                    preferred_language,
                    updated_at
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NOW())
                ON CONFLICT (user_id)
                DO UPDATE SET
                    push_alerts_enabled = EXCLUDED.push_alerts_enabled,
                    alert_threshold = EXCLUDED.alert_threshold,
                    default_persona = EXCLUDED.default_persona,
                    quiet_hours_start = EXCLUDED.quiet_hours_start,
                    quiet_hours_end = EXCLUDED.quiet_hours_end,
                    profile_based_alerting = EXCLUDED.profile_based_alerting,
                    preferred_language = EXCLUDED.preferred_language,
                    updated_at = NOW()
                RETURNING
                    user_id,
                    push_alerts_enabled,
                    alert_threshold,
                    default_persona,
                    quiet_hours_start,
                    quiet_hours_end,
                    profile_based_alerting,
                    preferred_language
                """,
                (
                    user_id,
                    payload.push_alerts_enabled,
                    payload.alert_threshold,
                    payload.default_persona,
                    payload.quiet_hours_start,
                    payload.quiet_hours_end,
                    payload.profile_based_alerting,
                    payload.preferred_language,
                ),
            )
            row = cur.fetchone()

    return UserSettingsResponse(
        user_id=str(row["user_id"]),
        push_alerts_enabled=bool(row["push_alerts_enabled"]),
        alert_threshold=row["alert_threshold"],
        default_persona=row["default_persona"],
        quiet_hours_start=int(row["quiet_hours_start"]),
        quiet_hours_end=int(row["quiet_hours_end"]),
        profile_based_alerting=bool(row["profile_based_alerting"]),
        preferred_language=row["preferred_language"] or "ru",
    )
