from datetime import date, timedelta

from app.services.health_analytics_service import _compute_trends, _direction_word, _t
from app.services.health_metrics import CANONICAL_METRICS, consent_allows_metric, is_known_metric


def test_mobility_metrics_are_canonical() -> None:
    for metric in (
        "walking_speed",
        "walking_step_length",
        "walking_asymmetry",
        "walking_double_support",
        "mindfulness_minutes",
        "basal_energy",
    ):
        assert is_known_metric(metric)


def test_mobility_consent_uses_fitness_or_activity() -> None:
    class Consent:
        fitnessEnabled = True
        activityEnabled = False
        stepsEnabled = False

    assert consent_allows_metric(Consent(), "walking_speed")


def test_trend_strings_exist_for_expanded_metrics() -> None:
    for key in (
        "trend_distance_title",
        "trend_active_energy_title",
        "trend_exercise_title",
        "trend_workout_title",
        "trend_spo2_title",
        "assoc_aqi_allergy_title",
        "assoc_sleep_hrv_title",
        "assoc_steps_feel_title",
    ):
        assert _t("ru", key)
        assert _t("en", key)
        assert _t("ru", key) != key


def test_compute_trends_includes_distance_when_enough_days() -> None:
    start = date.today() - timedelta(days=13)
    metrics = []
    for offset in range(14):
        day = start + timedelta(days=offset)
        metrics.append(
            {
                "local_date": day,
                "metric_type": "distance_walking_running",
                "value_avg": 3000.0 + offset * 100,
                "value_latest": None,
                "value_total": None,
            }
        )
    cards = _compute_trends(metrics, sleep_rows=[], lang="en", window_days=30)
    keys = {c.insightKey for c in cards}
    assert "trend_distance_walking_running" in keys
    assert _direction_word("en", 1.0) == "higher"


def test_canonical_count_grew() -> None:
    assert len(CANONICAL_METRICS) >= 36
