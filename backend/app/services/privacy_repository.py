from datetime import UTC, datetime
from typing import Any
from uuid import UUID

from app.services.db import get_connection


def export_user_data(user_id: str) -> dict[str, Any]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, email, created_at FROM users WHERE id = %s",
                (user_id,),
            )
            user = cur.fetchone()
            if user is None:
                raise ValueError("User not found")

            cur.execute(
                """
                SELECT
                    id,
                    persona_type,
                    sensitivity_level,
                    profile_type,
                    age_group,
                    heat_sensitivity_level,
                    respiratory_sensitivity_level,
                    activity_level,
                    location_name,
                    timezone,
                    home_lat,
                    home_lon,
                    created_at,
                    updated_at
                FROM profiles
                WHERE user_id = %s
                ORDER BY created_at DESC
                """,
                (user_id,),
            )
            profiles = cur.fetchall()
            profile_ids = [row["id"] for row in profiles]

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
                    preferred_language,
                    updated_at
                FROM user_settings
                WHERE user_id = %s
                """,
                (user_id,),
            )
            settings = cur.fetchone()

            cur.execute(
                """
                SELECT plan_id, status, starts_at, current_period_end, auto_renew, provider_subscription_id, updated_at
                FROM user_subscriptions
                WHERE user_id = %s
                """,
                (user_id,),
            )
            subscription = cur.fetchone()
            provider_subscription_id = (
                _as_text(subscription.get("provider_subscription_id"))
                if subscription and subscription.get("provider_subscription_id")
                else None
            )
            cur.execute(
                """
                SELECT user_id, local_time, timezone, enabled, last_sent_at, created_at, updated_at
                FROM briefing_schedule
                WHERE user_id = %s
                """,
                (user_id,),
            )
            briefing_schedule = cur.fetchone()

            cur.execute(
                """
                SELECT id, profile_id, platform, device_token, is_active, created_at, updated_at
                FROM push_device_tokens
                WHERE user_id = %s
                ORDER BY created_at DESC
                """,
                (user_id,),
            )
            device_tokens = cur.fetchall()

            cur.execute(
                """
                SELECT id, event_id, user_id, platform, device_token, provider_mode, attempt_no, success, status_code, reason, created_at
                FROM notification_delivery_attempts
                WHERE user_id = %s
                ORDER BY created_at DESC
                """,
                (user_id,),
            )
            delivery_attempts = cur.fetchall()

            symptoms: list[dict[str, Any]] = []
            risk_history: list[dict[str, Any]] = []
            notification_events: list[dict[str, Any]] = []
            risk_assessments: list[dict[str, Any]] = []
            ai_recommendations: list[dict[str, Any]] = []
            alert_events: list[dict[str, Any]] = []
            ai_explanation_events: list[dict[str, Any]] = []
            personal_correlations: list[dict[str, Any]] = []
            if profile_ids:
                cur.execute(
                    """
                    SELECT
                        id,
                        profile_id,
                        timestamp_utc,
                        cough,
                        wheeze,
                        headache,
                        fatigue,
                        sleep_quality,
                        symptom_type,
                        intensity,
                        note,
                        logged_at,
                        created_at
                    FROM symptom_logs
                    WHERE profile_id = ANY(%s)
                    ORDER BY created_at DESC
                    """,
                    (profile_ids,),
                )
                symptoms = cur.fetchall()

                cur.execute(
                    """
                    SELECT id, profile_id, snapshot_id, score_value, risk_level, recommendations_json, created_at
                    FROM risk_scores
                    WHERE profile_id = ANY(%s)
                    ORDER BY created_at DESC
                    """,
                    (profile_ids,),
                )
                risk_history = cur.fetchall()

                cur.execute(
                    """
                    SELECT id, profile_id, risk_level, should_send, message, created_at
                    FROM notification_events
                    WHERE profile_id = ANY(%s)
                    ORDER BY created_at DESC
                    """,
                    (profile_ids,),
                )
                notification_events = cur.fetchall()

                cur.execute(
                    """
                    SELECT
                        id,
                        user_profile_id,
                        environmental_snapshot_id,
                        overall_risk,
                        heat_risk,
                        air_risk,
                        outdoor_risk,
                        ventilation_risk,
                        safe_windows_json,
                        reason_codes_json,
                        recommendation_flags_json,
                        created_at
                    FROM risk_assessments
                    WHERE user_profile_id = ANY(%s)
                    ORDER BY created_at DESC
                    """,
                    (profile_ids,),
                )
                risk_assessments = cur.fetchall()

                cur.execute(
                    """
                    SELECT
                        r.id,
                        r.risk_assessment_id,
                        r.headline,
                        r.summary,
                        r.actions_json,
                        r.model_version,
                        r.created_at
                    FROM ai_recommendations r
                    JOIN risk_assessments ra ON ra.id = r.risk_assessment_id
                    WHERE ra.user_profile_id = ANY(%s)
                    ORDER BY r.created_at DESC
                    """,
                    (profile_ids,),
                )
                ai_recommendations = cur.fetchall()

                cur.execute(
                    """
                    SELECT
                        id,
                        user_profile_id,
                        alert_type,
                        severity,
                        title,
                        body,
                        dedupe_key,
                        sent_at,
                        delivery_status
                    FROM alert_events
                    WHERE user_profile_id = ANY(%s)
                    ORDER BY sent_at DESC
                    """,
                    (profile_ids,),
                )
                alert_events = cur.fetchall()

                cur.execute(
                    """
                    SELECT
                        id,
                        user_profile_id,
                        risk_assessment_id,
                        prompt_key,
                        prompt_version,
                        model_name,
                        used_fallback,
                        guardrail_blocked,
                        failure_reason,
                        generated_text,
                        created_at
                    FROM ai_explanation_events
                    WHERE user_profile_id = ANY(%s)
                    ORDER BY created_at DESC
                    """,
                    (profile_ids,),
                )
                ai_explanation_events = cur.fetchall()

                cur.execute(
                    """
                    SELECT
                        id,
                        profile_id,
                        factor_a,
                        factor_b,
                        coefficient,
                        p_value,
                        sample_size,
                        window_days,
                        computed_at
                    FROM personal_correlations
                    WHERE profile_id = ANY(%s)
                    ORDER BY computed_at DESC
                    """,
                    (profile_ids,),
                )
                personal_correlations = cur.fetchall()

            subscription_webhook_events: list[dict[str, Any]] = []
            if provider_subscription_id:
                cur.execute(
                    """
                    SELECT id, provider, event_id, event_type, provider_subscription_id, received_at
                    FROM subscription_webhook_events
                    WHERE provider_subscription_id = %s
                    ORDER BY received_at DESC
                    """,
                    (provider_subscription_id,),
                )
                subscription_webhook_events = cur.fetchall()

    return {
        "user": _serialize_row(user),
        "settings": _serialize_optional_row(settings),
        "subscription": _serialize_optional_row(subscription),
        "briefing_schedule": _serialize_optional_row(briefing_schedule),
        "profiles": _serialize_rows(profiles),
        "symptoms": _serialize_rows(symptoms),
        "risk_scores": _serialize_rows(risk_history),
        "notification_events": _serialize_rows(notification_events),
        "risk_assessments": _serialize_rows(risk_assessments),
        "ai_recommendations": _serialize_rows(ai_recommendations),
        "alert_events": _serialize_rows(alert_events),
        "ai_explanation_events": _serialize_rows(ai_explanation_events),
        "personal_correlations": _serialize_rows(personal_correlations),
        "device_tokens": _serialize_rows(device_tokens),
        "notification_delivery_attempts": _serialize_rows(delivery_attempts),
        "subscription_webhook_events": _serialize_rows(subscription_webhook_events),
    }


def delete_user_data(user_id: str) -> bool:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id
                FROM profiles
                WHERE user_id = %s
                """,
                (user_id,),
            )
            profile_ids = [row["id"] for row in cur.fetchall()]
            if profile_ids:
                cur.execute(
                    """
                    DELETE FROM ai_explanation_events
                    WHERE user_profile_id = ANY(%s)
                    """,
                    (profile_ids,),
                )
            cur.execute(
                """
                DELETE FROM notification_events ne
                USING profiles p
                WHERE ne.profile_id = p.id
                  AND p.user_id = %s
                """,
                (user_id,),
            )
            cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
            deleted = cur.rowcount > 0
    return deleted


def _serialize_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [_serialize_row(row) for row in rows]


def _serialize_optional_row(row: dict[str, Any] | None) -> dict[str, Any] | None:
    if row is None:
        return None
    return _serialize_row(row)


def _serialize_row(row: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in row.items():
        if isinstance(value, datetime):
            dt = value if value.tzinfo is not None else value.replace(tzinfo=UTC)
            result[key] = dt.isoformat()
        elif isinstance(value, UUID):
            result[key] = str(value)
        elif isinstance(value, (bytes, bytearray)):
            result[key] = value.decode("utf-8")
        else:
            result[key] = str(value) if key.endswith("_id") and value is not None else value
    return result


def _as_text(value: object | None) -> str | None:
    if value is None:
        return None
    if isinstance(value, (bytes, bytearray)):
        return value.decode("utf-8")
    return str(value)
