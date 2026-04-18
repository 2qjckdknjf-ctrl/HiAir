from datetime import datetime, timezone
import hashlib
from uuid import uuid4

from app.services.db import get_connection


def ensure_prompt_version(prompt_key: str, version: str, prompt_text: str) -> None:
    prompt_hash = hashlib.sha256(prompt_text.encode("utf-8")).hexdigest()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO ai_prompt_versions (id, prompt_key, version, prompt_hash, is_active, created_at)
                VALUES (%s, %s, %s, %s, TRUE, NOW())
                ON CONFLICT (prompt_key, version)
                DO UPDATE SET
                    prompt_hash = EXCLUDED.prompt_hash,
                    is_active = TRUE
                """,
                (str(uuid4()), prompt_key, version, prompt_hash),
            )


def save_explanation_event(
    profile_id: str | None,
    risk_assessment_id: str | None,
    prompt_key: str,
    prompt_version: str,
    model_name: str | None,
    used_fallback: bool,
    guardrail_blocked: bool,
    failure_reason: str | None,
    generated_text: str,
) -> str:
    event_id = str(uuid4())
    created_at = datetime.now(timezone.utc)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO ai_explanation_events (
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
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    event_id,
                    profile_id,
                    risk_assessment_id,
                    prompt_key,
                    prompt_version,
                    model_name,
                    used_fallback,
                    guardrail_blocked,
                    failure_reason,
                    generated_text,
                    created_at,
                ),
            )
    return event_id


def ai_event_summary(hours: int = 24) -> dict[str, int]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    COUNT(*)::int AS total,
                    SUM(CASE WHEN used_fallback THEN 1 ELSE 0 END)::int AS fallback_count,
                    SUM(CASE WHEN guardrail_blocked THEN 1 ELSE 0 END)::int AS guardrail_block_count,
                    SUM(CASE WHEN failure_reason = 'llm_timeout' THEN 1 ELSE 0 END)::int AS timeout_count,
                    SUM(CASE WHEN failure_reason = 'llm_network_error' THEN 1 ELSE 0 END)::int AS network_count,
                    SUM(CASE WHEN failure_reason = 'llm_server_error' THEN 1 ELSE 0 END)::int AS server_count
                FROM ai_explanation_events
                WHERE created_at >= NOW() - (%s || ' hours')::INTERVAL
                """,
                (hours,),
            )
            row = cur.fetchone()
    if row is None:
        return {
            "total": 0,
            "fallback_count": 0,
            "guardrail_block_count": 0,
            "timeout_count": 0,
            "network_count": 0,
            "server_count": 0,
        }
    return {
        "total": int(row["total"] or 0),
        "fallback_count": int(row["fallback_count"] or 0),
        "guardrail_block_count": int(row["guardrail_block_count"] or 0),
        "timeout_count": int(row["timeout_count"] or 0),
        "network_count": int(row["network_count"] or 0),
        "server_count": int(row["server_count"] or 0),
    }


def ai_event_trend(hours: int = 24) -> list[dict[str, int | str]]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    TO_CHAR(DATE_TRUNC('hour', created_at), 'YYYY-MM-DD"T"HH24:00:00"Z"') AS hour_bucket,
                    COUNT(*)::int AS total,
                    SUM(CASE WHEN used_fallback THEN 1 ELSE 0 END)::int AS fallback_count,
                    SUM(CASE WHEN guardrail_blocked THEN 1 ELSE 0 END)::int AS guardrail_block_count,
                    SUM(CASE WHEN failure_reason = 'llm_timeout' THEN 1 ELSE 0 END)::int AS timeout_count,
                    SUM(CASE WHEN failure_reason = 'llm_network_error' THEN 1 ELSE 0 END)::int AS network_count,
                    SUM(CASE WHEN failure_reason = 'llm_server_error' THEN 1 ELSE 0 END)::int AS server_count
                FROM ai_explanation_events
                WHERE created_at >= NOW() - (%s || ' hours')::INTERVAL
                GROUP BY DATE_TRUNC('hour', created_at)
                ORDER BY DATE_TRUNC('hour', created_at) ASC
                """,
                (hours,),
            )
            rows = cur.fetchall()
    return [
        {
            "hour": str(row["hour_bucket"]),
            "total": int(row["total"] or 0),
            "fallback_count": int(row["fallback_count"] or 0),
            "guardrail_block_count": int(row["guardrail_block_count"] or 0),
            "timeout_count": int(row["timeout_count"] or 0),
            "network_count": int(row["network_count"] or 0),
            "server_count": int(row["server_count"] or 0),
        }
        for row in rows
    ]


def ai_event_breakdown(hours: int = 24) -> dict[str, list[dict[str, int | str]]]:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    prompt_version,
                    COUNT(*)::int AS total,
                    SUM(CASE WHEN used_fallback THEN 1 ELSE 0 END)::int AS fallback_count,
                    SUM(CASE WHEN guardrail_blocked THEN 1 ELSE 0 END)::int AS guardrail_block_count
                FROM ai_explanation_events
                WHERE created_at >= NOW() - (%s || ' hours')::INTERVAL
                GROUP BY prompt_version
                ORDER BY total DESC, prompt_version ASC
                """,
                (hours,),
            )
            version_rows = cur.fetchall()
            cur.execute(
                """
                SELECT
                    COALESCE(model_name, 'unknown') AS model_name,
                    COUNT(*)::int AS total,
                    SUM(CASE WHEN used_fallback THEN 1 ELSE 0 END)::int AS fallback_count,
                    SUM(CASE WHEN guardrail_blocked THEN 1 ELSE 0 END)::int AS guardrail_block_count
                FROM ai_explanation_events
                WHERE created_at >= NOW() - (%s || ' hours')::INTERVAL
                GROUP BY COALESCE(model_name, 'unknown')
                ORDER BY total DESC, model_name ASC
                """,
                (hours,),
            )
            model_rows = cur.fetchall()
            cur.execute(
                """
                SELECT
                    CASE
                        WHEN failure_reason = 'llm_timeout' THEN 'timeout'
                        WHEN failure_reason = 'llm_network_error' THEN 'network'
                        WHEN failure_reason = 'llm_server_error' THEN 'server'
                        WHEN failure_reason IS NULL THEN 'none'
                        ELSE 'other'
                    END AS error_type,
                    COUNT(*)::int AS total
                FROM ai_explanation_events
                WHERE created_at >= NOW() - (%s || ' hours')::INTERVAL
                GROUP BY error_type
                ORDER BY total DESC, error_type ASC
                """,
                (hours,),
            )
            error_rows = cur.fetchall()

    by_prompt_version = [
        {
            "prompt_version": str(row["prompt_version"]),
            "total": int(row["total"] or 0),
            "fallback_count": int(row["fallback_count"] or 0),
            "guardrail_block_count": int(row["guardrail_block_count"] or 0),
        }
        for row in version_rows
    ]
    by_model_name = [
        {
            "model_name": str(row["model_name"]),
            "total": int(row["total"] or 0),
            "fallback_count": int(row["fallback_count"] or 0),
            "guardrail_block_count": int(row["guardrail_block_count"] or 0),
        }
        for row in model_rows
    ]
    by_error_type = [
        {
            "error_type": str(row["error_type"]),
            "total": int(row["total"] or 0),
        }
        for row in error_rows
        if str(row["error_type"]) != "none"
    ]
    return {
        "by_prompt_version": by_prompt_version,
        "by_model_name": by_model_name,
        "by_error_type": by_error_type,
    }
