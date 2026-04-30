from datetime import UTC, datetime

from app.services.briefing_service import _is_due


def test_is_due_true_when_local_time_matches_and_not_sent_recently() -> None:
    now_utc = datetime(2026, 5, 1, 5, 30, tzinfo=UTC)  # 07:30 in Europe/Madrid (summer)
    assert _is_due(
        now_utc=now_utc,
        local_time="07:30",
        timezone_name="Europe/Madrid",
        last_sent_at=None,
    )


def test_is_due_false_when_already_sent_recently() -> None:
    now_utc = datetime(2026, 5, 1, 5, 30, tzinfo=UTC)
    assert not _is_due(
        now_utc=now_utc,
        local_time="07:30",
        timezone_name="Europe/Madrid",
        last_sent_at="2026-05-01T00:30:00+00:00",
    )
