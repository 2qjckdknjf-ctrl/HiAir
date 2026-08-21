from datetime import datetime
from zoneinfo import ZoneInfo

from app.services.forecast.timeutil import attach_timezone


def test_barcelona_summer_offset_is_plus_two() -> None:
    iso = attach_timezone("2026-07-15T14:00", "Europe/Madrid")
    assert iso.endswith("+02:00")
    parsed = datetime.fromisoformat(iso)
    assert parsed.tzinfo is not None
    assert parsed.astimezone(ZoneInfo("Europe/Madrid")).hour == 14


def test_phoenix_has_no_dst() -> None:
    winter = attach_timezone("2026-01-15T12:00", "America/Phoenix")
    summer = attach_timezone("2026-07-15T12:00", "America/Phoenix")
    assert winter.endswith("-07:00")
    assert summer.endswith("-07:00")


def test_new_york_dst_spring_forward() -> None:
    before = attach_timezone("2026-03-08T01:00", "America/New_York")
    after = attach_timezone("2026-03-08T03:00", "America/New_York")
    assert before.endswith("-05:00")
    assert after.endswith("-04:00")


def test_new_york_dst_fall_back() -> None:
    before = attach_timezone("2026-11-01T01:00", "America/New_York")
    after = attach_timezone("2026-11-01T03:00", "America/New_York")
    assert "-04:00" in before or "-05:00" in before
    assert after.endswith("-05:00")


def test_dubai_riyadh_cairo_use_iana_offsets() -> None:
    assert attach_timezone("2026-08-21T16:00", "Asia/Dubai").endswith("+04:00")
    assert attach_timezone("2026-08-21T16:00", "Asia/Riyadh").endswith("+03:00")
    cairo = attach_timezone("2026-08-21T16:00", "Africa/Cairo")
    expected = datetime(2026, 8, 21, 16, tzinfo=ZoneInfo("Africa/Cairo")).isoformat()
    assert cairo == expected
    assert datetime.fromisoformat(cairo).hour == 16


def test_already_offset_iso_is_preserved() -> None:
    iso = attach_timezone("2026-07-15T14:00:00+02:00", "Europe/Madrid")
    assert iso.startswith("2026-07-15T14:00:00")
    assert "+02:00" in iso
