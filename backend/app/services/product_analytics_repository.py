from datetime import UTC, datetime, timedelta
from uuid import uuid4

from app.models.product_analytics import (
    AnalyticsEventCreate,
    AnalyticsEventResponse,
    CrashReportRequest,
    CrashReportResponse,
    FeedbackSubmitRequest,
    FeedbackSubmitResponse,
    KpiDashboardResponse,
)
from app.services.db import get_connection


def record_events(user_id: str | None, events: list[AnalyticsEventCreate]) -> list[AnalyticsEventResponse]:
    created: list[AnalyticsEventResponse] = []
    with get_connection() as conn:
        with conn.cursor() as cur:
            for event in events:
                event_id = str(uuid4())
                cur.execute(
                    """
                    INSERT INTO product_analytics_events (
                        id, user_id, session_id, event_name, properties, platform, app_version
                    )
                    VALUES (%s, %s, %s, %s, %s::jsonb, %s, %s)
                    RETURNING id, event_name, created_at
                    """,
                    (
                        event_id,
                        user_id,
                        event.session_id,
                        event.event_name.value,
                        _properties_json(event.properties),
                        event.platform,
                        event.app_version,
                    ),
                )
                row = cur.fetchone()
                created.append(
                    AnalyticsEventResponse(
                        id=str(row["id"]),
                        event_name=str(row["event_name"]),
                        created_at=row["created_at"],
                    )
                )
    return created


def submit_feedback(user_id: str | None, payload: FeedbackSubmitRequest) -> FeedbackSubmitResponse:
    feedback_id = str(uuid4())
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO product_feedback (
                    id, user_id, platform, liked, confusing, broken, contact_email, app_version
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id, created_at
                """,
                (
                    feedback_id,
                    user_id,
                    payload.platform,
                    payload.liked.strip(),
                    payload.confusing.strip(),
                    payload.broken.strip(),
                    payload.contact_email,
                    payload.app_version,
                ),
            )
            row = cur.fetchone()
    return FeedbackSubmitResponse(id=str(row["id"]), created_at=row["created_at"])


def submit_crash_report(user_id: str | None, payload: CrashReportRequest) -> CrashReportResponse:
    crash_id = str(uuid4())
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO product_crash_reports (
                    id, user_id, session_id, platform, message, stack_trace, app_version
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                RETURNING id, created_at
                """,
                (
                    crash_id,
                    user_id,
                    payload.session_id,
                    payload.platform,
                    payload.message.strip(),
                    payload.stack_trace,
                    payload.app_version,
                ),
            )
            row = cur.fetchone()
    return CrashReportResponse(id=str(row["id"]), created_at=row["created_at"])


def build_kpi_dashboard(window_days: int = 14) -> KpiDashboardResponse:
    window_days = max(1, min(window_days, 90))
    since = datetime.now(tz=UTC) - timedelta(days=window_days)
    d1_since = datetime.now(tz=UTC) - timedelta(days=1)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT event_name, COUNT(*) AS total
                FROM product_analytics_events
                WHERE created_at >= %s
                GROUP BY event_name
                """,
                (since,),
            )
            counts = {str(row["event_name"]): int(row["total"]) for row in cur.fetchall()}

            cur.execute(
                """
                SELECT COUNT(DISTINCT session_id) AS installs
                FROM product_analytics_events
                WHERE created_at >= %s
                  AND event_name IN ('app_install_tracked', 'onboarding_started')
                """,
                (since,),
            )
            installs_row = cur.fetchone()
            installs = int(installs_row["installs"] or 0) if installs_row else 0

            cur.execute(
                """
                SELECT COUNT(DISTINCT session_id) AS started
                FROM product_analytics_events
                WHERE created_at >= %s
                  AND event_name = 'onboarding_started'
                """,
                (since,),
            )
            started_row = cur.fetchone()
            onboarding_started = int(started_row["started"] or 0) if started_row else 0

            cur.execute(
                """
                SELECT COUNT(DISTINCT s.session_id) AS retained
                FROM product_analytics_events s
                WHERE s.event_name = 'onboarding_completed'
                  AND s.created_at >= %s
                  AND s.created_at < %s
                  AND EXISTS (
                      SELECT 1
                      FROM product_analytics_events d
                      WHERE d.session_id = s.session_id
                        AND d.event_name = 'dashboard_opened'
                        AND d.created_at > s.created_at
                        AND d.created_at <= s.created_at + INTERVAL '24 hours'
                  )
                """,
                (since, d1_since),
            )
            d1_row = cur.fetchone()
            d1_retained = int(d1_row["retained"] or 0) if d1_row else 0

            cur.execute(
                """
                SELECT COUNT(DISTINCT session_id) AS completed
                FROM product_analytics_events
                WHERE created_at >= %s
                  AND event_name = 'onboarding_completed'
                """,
                (since,),
            )
            completed_row = cur.fetchone()
            onboarding_completed = int(completed_row["completed"] or 0) if completed_row else 0

            cur.execute(
                """
                SELECT COUNT(DISTINCT session_id) AS completed
                FROM product_analytics_events
                WHERE created_at >= %s
                  AND created_at < %s
                  AND event_name = 'onboarding_completed'
                """,
                (since, d1_since),
            )
            d1_completed_row = cur.fetchone()
            d1_eligible_completed = int(d1_completed_row["completed"] or 0) if d1_completed_row else 0

            cur.execute(
                "SELECT COUNT(*) AS total FROM product_feedback WHERE created_at >= %s",
                (since,),
            )
            feedback_total = int(cur.fetchone()["total"] or 0)

            cur.execute(
                "SELECT COUNT(*) AS total FROM product_crash_reports WHERE created_at >= %s",
                (since,),
            )
            crash_total = int(cur.fetchone()["total"] or 0)
    completion_rate = 0.0
    if onboarding_started > 0:
        completion_rate = round((onboarding_completed / onboarding_started) * 100.0, 1)

    d1_rate = 0.0
    if d1_eligible_completed > 0:
        d1_rate = round((d1_retained / d1_eligible_completed) * 100.0, 1)

    return KpiDashboardResponse(
        window_days=window_days,
        installs_tracked=installs,
        onboarding_started=onboarding_started,
        onboarding_completed=onboarding_completed,
        onboarding_completion_rate_pct=completion_rate,
        d1_retention_pct=d1_rate,
        dashboard_opens=counts.get("dashboard_opened", 0),
        morning_briefing_opens=counts.get("morning_briefing_opened", 0),
        symptom_logs=counts.get("symptom_logged", 0),
        share_clicks=counts.get("share_card_clicked", 0),
        guest_mode_uses=counts.get("guest_mode_used", 0),
        feedback_submissions=feedback_total,
        crash_reports=crash_total,
    )


def _properties_json(properties: dict[str, str | int | float | bool | None]) -> str:
    import json

    return json.dumps(properties)
