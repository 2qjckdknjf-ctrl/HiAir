from pathlib import Path

from app.services.privacy_repository import _serialize_rows


def test_wearable_metrics_migration_is_idempotent() -> None:
    sql = Path("sql/006_wearable_metrics.sql").read_text(encoding="utf-8")
    assert "CREATE TABLE IF NOT EXISTS wearable_metrics" in sql
    assert "CREATE INDEX IF NOT EXISTS idx_wearable_metrics_user_recorded" in sql
    assert "REFERENCES users(id) ON DELETE CASCADE" in sql
    assert "REFERENCES profiles(id) ON DELETE SET NULL" in sql


def test_privacy_export_payload_includes_wearable_metrics_key() -> None:
    rows = [
        {
            "id": "wm-1",
            "profile_id": "profile-1",
            "recorded_at": "2026-06-20T08:00:00+00:00",
            "steps": 4200,
            "resting_heart_rate_bpm": 72,
            "hrv_ms": None,
            "sleep_hours": 7.5,
            "sleep_quality_score": 4,
            "source": "mobile",
            "created_at": "2026-06-20T08:00:00+00:00",
        }
    ]
    serialized = _serialize_rows(rows)
    assert len(serialized) == 1
    assert serialized[0]["steps"] == 4200


def test_privacy_repository_exports_wearable_metrics_section() -> None:
    source = Path("app/services/privacy_repository.py").read_text(encoding="utf-8")
    assert '"wearable_metrics": _serialize_rows(wearable_metrics)' in source
    assert "FROM wearable_metrics" in source
    assert "WHERE user_id = %s" in source
