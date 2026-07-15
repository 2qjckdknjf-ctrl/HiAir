"""Product analytics, feedback, crash reporting, and KPI dashboard tests."""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.api.deps import get_current_user_id
from app.main import app
from app.models.product_analytics import (
    AnalyticsEventResponse,
    CrashReportResponse,
    FeedbackSubmitResponse,
    KpiDashboardResponse,
)

client = TestClient(app)


def test_analytics_event_ingest_and_kpi():
    created = [
        AnalyticsEventResponse(
            id="e1",
            event_name="onboarding_started",
            created_at=datetime(2026, 6, 20, tzinfo=timezone.utc),
        ),
        AnalyticsEventResponse(
            id="e2",
            event_name="dashboard_opened",
            created_at=datetime(2026, 6, 20, tzinfo=timezone.utc),
        ),
    ]
    kpi = KpiDashboardResponse(
        window_days=14,
        installs_tracked=1,
        onboarding_started=1,
        onboarding_completed=1,
        onboarding_completion_rate_pct=100.0,
        d1_retention_pct=0.0,
        dashboard_opens=1,
        morning_briefing_opens=0,
        symptom_logs=0,
        share_clicks=0,
        guest_mode_uses=0,
        feedback_submissions=0,
        crash_reports=0,
    )
    with patch("app.api.product_analytics.product_analytics_repository.record_events", return_value=created):
        response = client.post(
            "/api/analytics/events",
            json={
                "events": [
                    {
                        "session_id": "sess-1",
                        "event_name": "onboarding_started",
                        "platform": "android",
                    },
                    {
                        "session_id": "sess-1",
                        "event_name": "dashboard_opened",
                        "platform": "android",
                    },
                ]
            },
        )
        assert response.status_code == 200
        assert response.json()["accepted"] == 2

    with patch(
        "app.api.product_analytics.product_analytics_repository.build_kpi_dashboard",
        return_value=kpi,
    ):
        app.dependency_overrides[get_current_user_id] = lambda: "user-1"
        try:
            kpi_response = client.get("/api/analytics/kpi-dashboard")
        finally:
            app.dependency_overrides.clear()
        assert kpi_response.status_code == 200
        assert kpi_response.json()["installs_tracked"] == 1


def test_feedback_endpoint():
    with patch(
        "app.api.product_analytics.product_analytics_repository.submit_feedback",
        return_value=FeedbackSubmitResponse(
            id="fb-1",
            created_at=datetime(2026, 6, 20, tzinfo=timezone.utc),
        ),
    ):
        response = client.post(
            "/api/feedback",
            json={
                "liked": "Morning briefing",
                "confusing": "Risk score",
                "broken": "",
                "platform": "ios",
            },
        )
        assert response.status_code == 200
        assert response.json()["id"] == "fb-1"


def test_crash_report_endpoint():
    with patch(
        "app.api.product_analytics.product_analytics_repository.submit_crash_report",
        return_value=CrashReportResponse(
            id="crash-1",
            created_at=datetime(2026, 6, 20, tzinfo=timezone.utc),
        ),
    ):
        response = client.post(
            "/api/crashes/report",
            json={
                "message": "NullPointer in Dashboard",
                "stack_trace": "at com.hiair...",
                "platform": "android",
            },
        )
        assert response.status_code == 200
        assert response.json()["id"] == "crash-1"


def test_launch_analytics_migration_is_idempotent() -> None:
    from pathlib import Path

    sql = Path("sql/007_launch_analytics.sql").read_text(encoding="utf-8")
    rollback = Path("sql/007_launch_analytics_rollback.sql").read_text(encoding="utf-8")
    assert "CREATE TABLE IF NOT EXISTS product_analytics_events" in sql
    assert "CREATE TABLE IF NOT EXISTS product_feedback" in sql
    assert "CREATE TABLE IF NOT EXISTS product_crash_reports" in sql
    assert "DROP TABLE IF EXISTS product_analytics_events" in rollback


def test_privacy_export_includes_launch_tables() -> None:
    from pathlib import Path

    source = Path("app/services/privacy_repository.py").read_text(encoding="utf-8")
    assert '"product_analytics_events": _serialize_rows(product_analytics_events)' in source
    assert '"product_feedback": _serialize_rows(product_feedback)' in source
    assert '"product_crash_reports": _serialize_rows(product_crash_reports)' in source
    assert "DELETE FROM product_analytics_events WHERE user_id = %s" in source
