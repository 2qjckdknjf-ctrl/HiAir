from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from app.models.health_intelligence import (
    ComprehensiveSymptomCreateRequest,
    ComprehensiveSymptomResponse,
    CustomSymptomCreateRequest,
    CustomSymptomResponse,
)
from app.services.db import get_connection
from app.services.symptom_taxonomy import (
    SAFETY_NOTICE,
    get_symptom,
    is_red_flag,
)


def create_comprehensive_entry(
    user_id: str,
    payload: ComprehensiveSymptomCreateRequest,
    language: str = "ru",
) -> ComprehensiveSymptomResponse:
    definition = get_symptom(payload.symptomType)
    category = definition.category if definition else (
        "custom" if payload.symptomType.startswith("custom:") else None
    )
    now = datetime.now(tz=timezone.utc)
    onset = payload.onsetAt or now
    client_request_id = (payload.clientRequestId or "").strip() or None
    with get_connection() as conn:
        with conn.cursor() as cur:
            if client_request_id:
                cur.execute(
                    """
                    SELECT id, symptom_type, category, severity, onset_at, duration_minutes,
                           ongoing, note, logged_at
                    FROM symptom_logs
                    WHERE user_id = %s
                      AND client_request_id = %s
                      AND deleted_at IS NULL
                    LIMIT 1
                    """,
                    (user_id, client_request_id),
                )
                existing = cur.fetchone()
                if existing is not None:
                    red = is_red_flag(str(existing["symptom_type"]))
                    lang = language if language in SAFETY_NOTICE else "en"
                    return ComprehensiveSymptomResponse(
                        id=str(existing["id"]),
                        profileId=payload.profileId,
                        symptomType=str(existing["symptom_type"]),
                        category=existing.get("category"),
                        severity=int(existing["severity"] or payload.severity),
                        onsetAt=existing.get("onset_at") or onset,
                        durationMinutes=existing.get("duration_minutes"),
                        ongoing=bool(existing.get("ongoing")),
                        note=existing.get("note"),
                        redFlag=red,
                        safetyNotice=SAFETY_NOTICE[lang] if red else None,
                        loggedAt=existing.get("logged_at") or now,
                    )

            symptom_id = str(uuid4())
            cur.execute(
                """
                INSERT INTO symptom_logs (
                    id, profile_id, user_id, timestamp_utc, logged_at,
                    cough, wheeze, headache, fatigue, sleep_quality,
                    symptom_type, intensity, severity, note, category,
                    onset_at, duration_minutes, ongoing, frequency,
                    body_context, suspected_trigger, activity_at_onset,
                    location_context, hydration_state, medication_taken,
                    timezone, is_custom, custom_label, client_request_id, created_at
                )
                VALUES (
                    %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s,
                    %s, %s, %s, %s,
                    %s, %s, %s,
                    %s, %s, %s,
                    %s, %s, %s, %s, NOW()
                )
                """,
                (
                    symptom_id,
                    payload.profileId,
                    user_id,
                    onset,
                    now,
                    payload.symptomType in {"cough", "dry_cough", "wet_cough"},
                    payload.symptomType == "wheeze",
                    payload.symptomType in {"headache", "migraine_like_pain"},
                    payload.symptomType in {"fatigue", "weakness", "low_energy"},
                    3,
                    payload.symptomType,
                    payload.severity,
                    payload.severity,
                    payload.note,
                    category,
                    onset,
                    payload.durationMinutes,
                    payload.ongoing,
                    payload.frequency,
                    payload.bodyContext,
                    payload.suspectedTrigger,
                    payload.activityAtOnset,
                    payload.locationContext,
                    payload.hydrationState,
                    payload.medicationTaken,
                    payload.timezone,
                    payload.symptomType.startswith("custom:") or bool(payload.customLabel),
                    payload.customLabel,
                    client_request_id,
                ),
            )
    red = is_red_flag(payload.symptomType)
    lang = language if language in SAFETY_NOTICE else "en"
    return ComprehensiveSymptomResponse(
        id=symptom_id,
        profileId=payload.profileId,
        symptomType=payload.symptomType,
        category=category,
        severity=payload.severity,
        onsetAt=onset,
        durationMinutes=payload.durationMinutes,
        ongoing=payload.ongoing,
        note=payload.note,
        redFlag=red,
        safetyNotice=SAFETY_NOTICE[lang] if red else None,
        loggedAt=now,
    )


def soft_delete_entry(user_id: str, profile_id: str, entry_id: str) -> bool:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE symptom_logs
                SET deleted_at = NOW()
                WHERE id = %s
                  AND profile_id = %s
                  AND (user_id = %s OR user_id IS NULL)
                  AND deleted_at IS NULL
                """,
                (entry_id, profile_id, user_id),
            )
            return cur.rowcount > 0


def update_entry(
    user_id: str,
    profile_id: str,
    entry_id: str,
    *,
    severity: int | None = None,
    note: str | None = None,
    duration_minutes: int | None = None,
    ongoing: bool | None = None,
) -> dict[str, Any] | None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, severity, note, duration_minutes, ongoing
                FROM symptom_logs
                WHERE id = %s AND profile_id = %s AND deleted_at IS NULL
                """,
                (entry_id, profile_id),
            )
            row = cur.fetchone()
            if row is None:
                return None
            cur.execute(
                """
                UPDATE symptom_logs
                SET severity = COALESCE(%s, severity),
                    intensity = COALESCE(%s, intensity),
                    note = COALESCE(%s, note),
                    duration_minutes = COALESCE(%s, duration_minutes),
                    ongoing = COALESCE(%s, ongoing)
                WHERE id = %s AND profile_id = %s
                RETURNING id, symptom_type, severity, note, duration_minutes, ongoing, logged_at
                """,
                (
                    severity,
                    severity,
                    note,
                    duration_minutes,
                    ongoing,
                    entry_id,
                    profile_id,
                ),
            )
            return cur.fetchone()


def create_custom_symptom(user_id: str, payload: CustomSymptomCreateRequest) -> CustomSymptomResponse:
    custom_id = str(uuid4())
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO custom_symptoms (
                    id, user_id, profile_id, label, category, icon_key, is_hidden, created_at, updated_at
                )
                VALUES (%s, %s, %s, %s, %s, %s, FALSE, NOW(), NOW())
                ON CONFLICT (user_id, profile_id, label)
                DO UPDATE SET updated_at = NOW(), is_hidden = FALSE
                RETURNING id, label, category, icon_key, is_hidden
                """,
                (
                    custom_id,
                    user_id,
                    payload.profileId,
                    payload.label.strip(),
                    payload.category,
                    payload.iconKey,
                ),
            )
            row = cur.fetchone()
    return CustomSymptomResponse(
        id=str(row["id"]),
        symptomType=f"custom:{row['id']}",
        label=str(row["label"]),
        category=str(row["category"]),
        iconKey=row.get("icon_key"),
        isHidden=bool(row["is_hidden"]),
    )


def list_custom_symptoms(user_id: str, profile_id: str) -> list[CustomSymptomResponse]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, label, category, icon_key, is_hidden
                FROM custom_symptoms
                WHERE user_id = %s AND profile_id = %s AND is_hidden = FALSE
                ORDER BY created_at DESC
                """,
                (user_id, profile_id),
            )
            rows = cur.fetchall()
    return [
        CustomSymptomResponse(
            id=str(row["id"]),
            symptomType=f"custom:{row['id']}",
            label=str(row["label"]),
            category=str(row["category"]),
            iconKey=row.get("icon_key"),
            isHidden=bool(row["is_hidden"]),
        )
        for row in rows
    ]


def set_favorite(user_id: str, profile_id: str, symptom_type: str, enabled: bool) -> None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            if not enabled:
                cur.execute(
                    """
                    DELETE FROM symptom_favorites
                    WHERE user_id = %s AND profile_id = %s AND symptom_type = %s
                    """,
                    (user_id, profile_id, symptom_type),
                )
                return
            cur.execute(
                """
                INSERT INTO symptom_favorites (id, user_id, profile_id, symptom_type, sort_order, created_at)
                VALUES (%s, %s, %s, %s, 0, NOW())
                ON CONFLICT (user_id, profile_id, symptom_type) DO NOTHING
                """,
                (str(uuid4()), user_id, profile_id, symptom_type),
            )


def list_favorites(user_id: str, profile_id: str) -> list[str]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT symptom_type
                FROM symptom_favorites
                WHERE user_id = %s AND profile_id = %s
                ORDER BY sort_order ASC, created_at ASC
                """,
                (user_id, profile_id),
            )
            return [str(row["symptom_type"]) for row in cur.fetchall()]
