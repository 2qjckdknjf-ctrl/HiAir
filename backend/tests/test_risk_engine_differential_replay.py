"""Differential replay for deterministic Risk Engine behavior (Nov 28 P0).

Baseline and candidate are the same evaluate_risk implementation: identical
inputs must yield identical risk scores/levels/reason codes. Stale/missing AQI
must not invent zeros or change approved thresholds.
"""

from __future__ import annotations

import copy

from app.models.air import EnvironmentalInput, ProfileType, UserProfileContext
from app.services.air_risk_engine import evaluate_risk


def _profile() -> UserProfileContext:
    return UserProfileContext(
        profile_id="replay-1",
        user_id="user-1",
        profile_type=ProfileType.ADULT_DEFAULT,
        age_group="adult",
        heat_sensitivity_level=2,
        respiratory_sensitivity_level=2,
        activity_level="moderate",
        timezone="Europe/Madrid",
        home_lat=41.39,
        home_lon=2.17,
    )


def _environment(**overrides: object) -> EnvironmentalInput:
    values: dict[str, object] = {
        "lat": 41.39,
        "lon": 2.17,
        "temperature": 28.0,
        "feels_like": 29.0,
        "humidity": 45.0,
        "aqi": 55,
        "pm25": 12.0,
        "pm10": 20.0,
        "ozone": 40.0,
        "no2": 15.0,
        "uv": 5.0,
        "wind_speed": 2.0,
        "source": "live",
        "timestamp": "2026-11-28T10:00:00+00:00",
        "timezone": "Europe/Madrid",
    }
    values.update(overrides)
    return EnvironmentalInput(**values)  # type: ignore[arg-type]


def _fingerprint(result: object) -> dict[str, object]:
    return {
        "overall": result.overallRisk.value,
        "heat": result.heatRisk.value,
        "air": result.airRisk.value,
        "outdoor": result.outdoorRisk.value,
        "indoor": result.indoorVentilationRisk.value,
        "flags": list(result.recommendationFlags),
        "reasons": list(result.reasonCodes),
        "windows": [(w.type, w.start, w.end) for w in result.safeWindows],
    }


def test_identical_inputs_replay_byte_stable() -> None:
    env = _environment()
    baseline = _fingerprint(evaluate_risk(_profile(), copy.deepcopy(env)))
    candidate = _fingerprint(evaluate_risk(_profile(), copy.deepcopy(env)))
    assert candidate == baseline


def test_missing_aqi_does_not_become_zero_and_stays_replay_stable() -> None:
    env = _environment(aqi=None, pm25=None, pm10=None, ozone=None, no2=None)
    first = evaluate_risk(_profile(), copy.deepcopy(env))
    second = evaluate_risk(_profile(), copy.deepcopy(env))
    assert _fingerprint(first) == _fingerprint(second)
    assert "air_data_unavailable" in first.reasonCodes
    assert first.airRisk.value == "moderate"
    # Explicit zero remains a valid reading and must differ from missing.
    zero = evaluate_risk(_profile(), _environment(aqi=0, pm25=0.0, pm10=0.0, ozone=0.0))
    assert _fingerprint(zero) != _fingerprint(first)
    assert "air_data_unavailable" not in zero.reasonCodes


def test_stale_source_label_does_not_change_thresholds() -> None:
    live = _fingerprint(evaluate_risk(_profile(), _environment(source="live", aqi=90)))
    cached = _fingerprint(evaluate_risk(_profile(), _environment(source="cached", aqi=90)))
    # Deterministic scoring depends on metrics, not honesty label string.
    assert live["overall"] == cached["overall"]
    assert live["air"] == cached["air"]
