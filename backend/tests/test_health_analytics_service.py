"""Unit tests for explainable health analytics (no DB)."""

from __future__ import annotations

from datetime import date, timedelta
from unittest.mock import MagicMock
from uuid import uuid4

from app.services import health_analytics_service as analytics


def _day(offset: int) -> date:
    return date.today() - timedelta(days=offset)


def _metric(day: date, metric_type: str, *, avg: float | None = None, total: float | None = None) -> dict:
    return {
        "local_date": day,
        "metric_type": metric_type,
        "value_avg": avg,
        "value_total": total,
        "value_latest": None,
        "quality_state": "ok",
    }


def test_row_primary_value_skips_missing() -> None:
    assert analytics._row_primary_value({"value_avg": None, "value_total": None, "value_latest": None}) is None
    assert analytics._row_primary_value({"value_avg": None, "value_total": 12.0, "value_latest": None}) == 12.0
    assert analytics._metric_value([], "steps") is None
    assert analytics._metric_value([_metric(_day(0), "steps", total=100)], "hrv_sdnn") is None


def test_series_excludes_null_metrics() -> None:
    metrics = [
        _metric(_day(2), "steps", total=None),
        _metric(_day(1), "steps", total=5000),
        _metric(_day(0), "steps", total=6000),
    ]
    series = analytics._series_for_metric(metrics, "steps")
    assert len(series) == 2
    assert all(v is not None for _, v in series)


def test_insufficient_data_cards_honest() -> None:
    cards = analytics._insufficient_data_cards(
        metrics=[],
        sleep_rows=[],
        symptoms_by_day={},
        lang="en",
        window_days=30,
    )
    keys = {c["key"] for c in cards}
    assert "need_symptoms" in keys
    assert "need_sleep" in keys
    assert "need_heart" in keys
    assert all(c["have"] != "0" or c["have"] == 0 for c in cards)


def test_compute_trends_requires_minimum_days() -> None:
    # Fewer than compare window → no trend cards
    metrics = [_metric(_day(i), "steps", total=1000 + i * 100) for i in range(3)]
    cards = analytics._compute_trends(metrics, [], "en", 30)
    assert cards == []

    # Exactly 10 days is not enough for recent-vs-older compare (needs 14).
    metrics = [_metric(_day(i), "steps", total=1000 + i * 200) for i in range(10)]
    cards = analytics._compute_trends(metrics, [], "en", 30)
    assert cards == []

    metrics = [_metric(_day(i), "steps", total=1000 + i * 200) for i in range(14)]
    cards = analytics._compute_trends(metrics, [], "en", 30)
    assert any(c.insightKey == "trend_steps" for c in cards)
    for card in cards:
        blob = f"{card.title} {card.observation} {card.recommendation} {' '.join(card.limitations)}"
        assert "diagnosis" not in blob.lower() or "not a diagnosis" in blob.lower()
        assert "causation" in " ".join(card.limitations).lower() or "association" in " ".join(card.limitations).lower()


def test_association_pm25_cough_minimum_and_wording() -> None:
    env = {}
    symptoms = {}
    for i in range(8):
        d = _day(i)
        env[d] = {"pm25": 50.0, "aqi": 120.0, "temperature": 32.0}
        symptoms[d] = [{"symptomType": "cough", "severity": 3}]
    sleep = [{"local_date": _day(i), "total_minutes": 360} for i in range(8)]
    rhr = [_metric(_day(i), "resting_heart_rate", avg=70.0 + (10 if i == 0 else 0)) for i in range(10)]

    cards = analytics._compute_associations(env, symptoms, rhr, sleep, "en", 30)
    assert cards
    text = " ".join(
        f"{c.title} {c.observation} {c.recommendation} {' '.join(c.limitations)}" for c in cards
    ).lower()
    assert "causation" in text or "association" in text
    assert "diagnos" not in text or "does not provide medical diagnoses" in text
    assert "caused by" not in text


def test_build_insights_bundle_missing_stays_none(monkeypatch) -> None:
    user_id = "user-analytics"
    profile_id = str(uuid4())
    today = date.today()

    monkeypatch.setattr(
        analytics.health_sync_repository,
        "list_metrics_window",
        lambda *a, **k: [_metric(today, "steps", total=1000)],
    )
    monkeypatch.setattr(analytics.health_sync_repository, "get_sleep_window", lambda *a, **k: [])
    monkeypatch.setattr(analytics.health_sync_repository, "get_sync_state", lambda *a, **k: None)
    monkeypatch.setattr(analytics, "_load_environment_by_day", lambda *a, **k: {})
    monkeypatch.setattr(analytics, "_load_symptoms_by_day", lambda *a, **k: {})
    monkeypatch.setattr(analytics, "_load_risk_by_day", lambda *a, **k: {})
    monkeypatch.setattr(
        analytics.wearable_repository,
        "get_active_consent",
        lambda *a, **k: MagicMock(isActive=True),
    )

    bundle = analytics.build_insights_bundle(
        user_id=user_id,
        profile_id=profile_id,
        window_days=30,
        language="en",
    )
    assert bundle["today"]["steps"] == 1000.0
    assert bundle["today"]["restingHeartRate"] is None
    assert bundle["today"]["hrv"] is None
    assert bundle["today"]["sleepMinutes"] is None
    assert bundle["today"]["oxygenSaturation"] is None
    assert any(c["key"] == "need_symptoms" for c in bundle["insufficientData"])
    assert bundle["healthDataStatus"]["metricDays"] == 1


def test_build_timeline_preserves_null_health(monkeypatch) -> None:
    user_id = "user-timeline"
    profile_id = str(uuid4())
    today = date.today()

    monkeypatch.setattr(
        analytics.health_sync_repository,
        "list_metrics_window",
        lambda *a, **k: [_metric(today, "steps", total=2000)],
    )
    monkeypatch.setattr(analytics.health_sync_repository, "get_sleep_window", lambda *a, **k: [])
    monkeypatch.setattr(analytics, "_load_environment_by_day", lambda *a, **k: {today: {"pm25": None}})
    monkeypatch.setattr(analytics, "_load_symptoms_by_day", lambda *a, **k: {})
    monkeypatch.setattr(analytics, "_load_risk_by_day", lambda *a, **k: {})

    points = analytics.build_timeline(user_id=user_id, profile_id=profile_id, window_days=3)
    assert len(points) == 3
    today_point = next(p for p in points if p["localDate"] == today)
    assert today_point["health"].get("steps") == 2000.0
    # Days without metrics should not invent zeros
    empty = next(p for p in points if p["localDate"] == today - timedelta(days=1))
    assert empty["health"] == {} or "steps" not in empty["health"]


def test_direction_and_t_helpers() -> None:
    assert "higher" in analytics._direction_word("en", 1.0)
    assert "lower" in analytics._direction_word("en", -1.0)
    assert "change" in analytics._direction_word("en", 0.0)
    text = analytics._t("en", "limitation_not_causal")
    assert "not proven causation" in text
    assert analytics._t("en", "missing_key_xyz") == "missing_key_xyz"
