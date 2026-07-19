"""Canonical health metric identifiers and validation helpers."""

from __future__ import annotations

CANONICAL_METRICS: dict[str, dict[str, str]] = {
    "steps": {"unit": "count", "category": "activity", "tier": "1"},
    "distance_walking_running": {"unit": "m", "category": "activity", "tier": "1"},
    "active_energy": {"unit": "kcal", "category": "activity", "tier": "1"},
    "basal_energy": {"unit": "kcal", "category": "activity", "tier": "1"},
    "exercise_minutes": {"unit": "min", "category": "activity", "tier": "1"},
    "stand_minutes": {"unit": "min", "category": "activity", "tier": "1"},
    "flights_climbed": {"unit": "count", "category": "activity", "tier": "1"},
    "workout_count": {"unit": "count", "category": "workouts", "tier": "1"},
    "workout_duration": {"unit": "min", "category": "workouts", "tier": "1"},
    "heart_rate": {"unit": "bpm", "category": "cardiovascular", "tier": "2"},
    "resting_heart_rate": {"unit": "bpm", "category": "cardiovascular", "tier": "2"},
    "walking_heart_rate_avg": {"unit": "bpm", "category": "cardiovascular", "tier": "2"},
    "hrv_sdnn": {"unit": "ms", "category": "cardiovascular", "tier": "2"},
    "hrv_rmssd": {"unit": "ms", "category": "cardiovascular", "tier": "2"},
    "respiratory_rate": {"unit": "breaths_per_min", "category": "respiratory", "tier": "3"},
    "oxygen_saturation": {"unit": "percent", "category": "respiratory", "tier": "3"},
    "sleep_total": {"unit": "min", "category": "sleep", "tier": "1"},
    "sleep_in_bed": {"unit": "min", "category": "sleep", "tier": "1"},
    "sleep_awake": {"unit": "min", "category": "sleep", "tier": "1"},
    "sleep_core_light": {"unit": "min", "category": "sleep", "tier": "1"},
    "sleep_deep": {"unit": "min", "category": "sleep", "tier": "1"},
    "sleep_rem": {"unit": "min", "category": "sleep", "tier": "1"},
    "body_temperature": {"unit": "celsius", "category": "temperature", "tier": "3"},
    "wrist_temperature": {"unit": "celsius", "category": "temperature", "tier": "3"},
    "vo2_max": {"unit": "ml_kg_min", "category": "fitness", "tier": "2"},
    "mindfulness_minutes": {"unit": "min", "category": "fitness", "tier": "2"},
    "weight": {"unit": "kg", "category": "body", "tier": "4"},
    "height": {"unit": "cm", "category": "body", "tier": "4"},
    "body_fat": {"unit": "percent", "category": "body", "tier": "4"},
    "blood_pressure_systolic": {"unit": "mmHg", "category": "sensitive", "tier": "4"},
    "blood_pressure_diastolic": {"unit": "mmHg", "category": "sensitive", "tier": "4"},
    "blood_glucose": {"unit": "mg_dL", "category": "sensitive", "tier": "4"},
}

QUALITY_STATES = frozenset(
    {
        "ok",
        "partial",
        "no_records",
        "permission_unknown",
        "permission_denied",
        "source_unavailable",
        "stale",
        "sync_error",
        "unsupported",
    }
)

HRV_METHODS = frozenset({"sdnn", "rmssd"})

# Metrics that may enter personal load / risk amplification (wellness only).
RISK_SAFE_METRICS = frozenset(
    {
        "steps",
        "active_energy",
        "exercise_minutes",
        "heart_rate",
        "resting_heart_rate",
        "sleep_total",
        "hrv_sdnn",
        "hrv_rmssd",
    }
)

SENSITIVE_METRICS = frozenset(
    {
        "blood_pressure_systolic",
        "blood_pressure_diastolic",
        "blood_glucose",
        "weight",
        "height",
        "body_fat",
    }
)


def is_known_metric(metric_type: str) -> bool:
    return metric_type in CANONICAL_METRICS


def expected_unit(metric_type: str) -> str | None:
    meta = CANONICAL_METRICS.get(metric_type)
    return meta["unit"] if meta else None


def is_sensitive(metric_type: str) -> bool:
    return metric_type in SENSITIVE_METRICS


_SLEEP_STAGE_METRICS = frozenset(
    {"sleep_awake", "sleep_core_light", "sleep_deep", "sleep_rem"}
)


def consent_allows_metric(consent: object, metric_type: str) -> bool:
    """Enforce per-category consent flags for a canonical metric.

    `consent` is a WearableConsentResponse-like object with boolean attributes.
    Unknown metrics are denied.
    """
    meta = CANONICAL_METRICS.get(metric_type)
    if meta is None:
        return False

    def _flag(name: str) -> bool:
        return bool(getattr(consent, name, False))

    if metric_type == "steps":
        return _flag("stepsEnabled") or _flag("activityEnabled")

    category = meta["category"]
    if category == "activity":
        return _flag("activityEnabled") or _flag("stepsEnabled")
    if category == "workouts":
        return _flag("workoutsEnabled") or _flag("activityEnabled")
    if category == "cardiovascular":
        if metric_type == "resting_heart_rate":
            return _flag("restingHeartRateEnabled") or _flag("heartRateEnabled")
        if metric_type.startswith("hrv_"):
            return _flag("hrvEnabled")
        return _flag("heartRateEnabled")
    if category == "sleep":
        if metric_type in _SLEEP_STAGE_METRICS:
            return _flag("sleepEnabled") and _flag("sleepStagesEnabled")
        return _flag("sleepEnabled")
    if category == "respiratory":
        return _flag("respiratoryEnabled")
    if category == "temperature":
        return _flag("temperatureEnabled")
    if category == "fitness":
        return _flag("fitnessEnabled")
    if category == "body":
        return _flag("bodyMetricsEnabled")
    if category == "sensitive":
        return _flag("sensitiveMetricsEnabled")
    return False


def consent_allows_sleep_summary(consent: object, *, has_stages: bool) -> bool:
    if not bool(getattr(consent, "sleepEnabled", False)):
        return False
    if has_stages and not bool(getattr(consent, "sleepStagesEnabled", False)):
        return False
    return True
