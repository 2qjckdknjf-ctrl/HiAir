from datetime import datetime, timedelta, timezone
from uuid import uuid4

from psycopg.types.json import Jsonb

from app.models.air import (
    EnvironmentalInput,
    ProfileType,
    RecommendationCard,
    RiskAssessmentResult,
    SymptomHistoryItem,
    UserProfileContext,
)
from app.services.db import get_connection


PERSONA_TO_PROFILE_TYPE = {
    "adult": ProfileType.ADULT_DEFAULT,
    "child": ProfileType.CHILD,
    "elderly": ProfileType.ELDERLY,
    "asthma": ProfileType.ASTHMA_SENSITIVE,
    "allergy": ProfileType.ALLERGY_SENSITIVE,
    "runner": ProfileType.RUNNER,
    "worker": ProfileType.OUTDOOR_WORKER,
}


def get_profile_context(profile_id: str) -> UserProfileContext | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    id,
                    user_id,
                    profile_type,
                    persona_type,
                    age_group,
                    heat_sensitivity_level,
                    respiratory_sensitivity_level,
                    activity_level,
                    location_name,
                    timezone,
                    home_lat,
                    home_lon
                FROM profiles
                WHERE id = %s
                LIMIT 1
                """,
                (profile_id,),
            )
            row = cur.fetchone()
    if row is None:
        return None

    profile_type = _as_text(row["profile_type"])
    persona_type = _as_text(row["persona_type"])
    if not profile_type:
        profile_type = PERSONA_TO_PROFILE_TYPE.get(persona_type, ProfileType.ADULT_DEFAULT).value

    return UserProfileContext(
        profile_id=str(row["id"]),
        user_id=str(row["user_id"]),
        profile_type=ProfileType(profile_type),
        age_group=_as_text(row["age_group"]) or "adult",
        heat_sensitivity_level=int(row["heat_sensitivity_level"] or 2),
        respiratory_sensitivity_level=int(row["respiratory_sensitivity_level"] or 2),
        activity_level=_as_text(row["activity_level"]) or "moderate",
        location_name=_as_text(row["location_name"]),
        timezone=_as_text(row["timezone"]) or "UTC",
        home_lat=float(row["home_lat"]),
        home_lon=float(row["home_lon"]),
    )


def _as_text(value: object | None) -> str | None:
    if value is None:
        return None
    if isinstance(value, (bytes, bytearray)):
        return value.decode("utf-8")
    return str(value)


def save_environment_snapshot(environment: EnvironmentalInput) -> str:
    snapshot_id = str(uuid4())
    geo_hash = f"{round(environment.lat, 2)}:{round(environment.lon, 2)}"
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO environment_snapshots (
                    id,
                    region_key,
                    timestamp_utc,
                    temperature_c,
                    humidity_percent,
                    aqi,
                    pm25,
                    ozone,
                    source,
                    geo_hash,
                    lat,
                    lon,
                    feels_like,
                    pm10,
                    uv,
                    wind_speed
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    snapshot_id,
                    geo_hash,
                    environment.timestamp,
                    environment.temperature,
                    environment.humidity,
                    environment.aqi,
                    environment.pm25,
                    environment.ozone,
                    environment.source,
                    geo_hash,
                    environment.lat,
                    environment.lon,
                    environment.feels_like,
                    environment.pm10,
                    environment.uv,
                    environment.wind_speed,
                ),
            )
    return snapshot_id


def save_risk_assessment(
    profile_id: str,
    snapshot_id: str,
    risk: RiskAssessmentResult,
) -> str:
    assessment_id = str(uuid4())
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO risk_assessments (
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
                    recommendation_flags_json
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    assessment_id,
                    profile_id,
                    snapshot_id,
                    risk.overallRisk.value,
                    risk.heatRisk.value,
                    risk.airRisk.value,
                    risk.outdoorRisk.value,
                    risk.indoorVentilationRisk.value,
                    Jsonb([window.model_dump() for window in risk.safeWindows]),
                    Jsonb(risk.reasonCodes),
                    Jsonb(risk.recommendationFlags),
                ),
            )
    return assessment_id


def save_recommendation(
    risk_assessment_id: str,
    recommendation: RecommendationCard,
    model_version: str,
) -> str:
    recommendation_id = str(uuid4())
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO ai_recommendations (
                    id,
                    risk_assessment_id,
                    headline,
                    summary,
                    actions_json,
                    model_version
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    recommendation_id,
                    risk_assessment_id,
                    recommendation.headline,
                    recommendation.summary,
                    Jsonb(recommendation.actions),
                    model_version,
                ),
            )
    return recommendation_id


def get_latest_risk_assessment(profile_id: str) -> dict[str, str] | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    id,
                    overall_risk,
                    created_at
                FROM risk_assessments
                WHERE user_profile_id = %s
                ORDER BY created_at DESC
                LIMIT 1
                """,
                (profile_id,),
            )
            row = cur.fetchone()
    if row is None:
        return None
    return {
        "id": str(row["id"]),
        "overall_risk": str(row["overall_risk"]),
        "created_at": row["created_at"].isoformat(),
    }


def find_recent_alert_by_dedupe_key(dedupe_key: str, within_hours: int = 6) -> bool:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=within_hours)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1
                FROM alert_events
                WHERE dedupe_key = %s
                  AND sent_at >= %s
                LIMIT 1
                """,
                (dedupe_key, cutoff),
            )
            row = cur.fetchone()
    return row is not None


def save_alert_event(
    profile_id: str,
    alert_type: str,
    severity: str,
    title: str,
    body: str,
    dedupe_key: str,
    delivery_status: str,
) -> str:
    event_id = str(uuid4())
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO alert_events (
                    id,
                    user_profile_id,
                    alert_type,
                    severity,
                    title,
                    body,
                    dedupe_key,
                    sent_at,
                    delivery_status
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, NOW(), %s)
                """,
                (event_id, profile_id, alert_type, severity, title, body, dedupe_key, delivery_status),
            )
    return event_id


def create_symptom_entry(
    profile_id: str,
    symptom_type: str,
    intensity: int,
    note: str | None,
) -> SymptomHistoryItem:
    symptom_id = str(uuid4())
    logged_at = datetime.now(timezone.utc)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO symptom_logs (
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
                    logged_at
                )
                VALUES (%s, %s, %s, FALSE, FALSE, FALSE, FALSE, 3, %s, %s, %s, %s)
                """,
                (symptom_id, profile_id, logged_at, symptom_type, intensity, note, logged_at),
            )
    return SymptomHistoryItem(
        id=symptom_id,
        profileId=profile_id,
        symptomType=symptom_type,
        intensity=intensity,
        note=note,
        loggedAt=logged_at.isoformat(),
    )


def get_symptom_history(profile_id: str, limit: int = 50) -> list[SymptomHistoryItem]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, profile_id, symptom_type, intensity, note, logged_at
                FROM symptom_logs
                WHERE profile_id = %s
                  AND symptom_type IS NOT NULL
                ORDER BY logged_at DESC
                LIMIT %s
                """,
                (profile_id, limit),
            )
            rows = cur.fetchall()
    return [
        SymptomHistoryItem(
            id=str(row["id"]),
            profileId=str(row["profile_id"]),
            symptomType=str(row["symptom_type"]),
            intensity=int(row["intensity"] or 1),
            note=row["note"],
            loggedAt=row["logged_at"].isoformat(),
        )
        for row in rows
    ]
