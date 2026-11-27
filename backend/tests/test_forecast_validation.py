import pytest

from app.services.forecast.validation import (
    ForecastObservationPair,
    assert_no_future_leakage,
    evaluate_pairs,
)


def _pair(**overrides: object) -> ForecastObservationPair:
    values = {
        "location_key": "bcn",
        "provider": "openmeteo",
        "provider_version": "v1",
        "metric": "aqi",
        "issued_at": "2026-11-01T00:00:00+00:00",
        "target_at": "2026-11-01T12:00:00+00:00",
        "forecast_value": 40.0,
        "observed_at": "2026-11-01T12:05:00+00:00",
        "observed_value": 42.0,
        "availability_at": "2026-11-01T00:00:00+00:00",
    }
    values.update(overrides)
    return ForecastObservationPair(**values)  # type: ignore[arg-type]


def test_future_leakage_rejected() -> None:
    with pytest.raises(ValueError, match="future leakage"):
        assert_no_future_leakage(
            _pair(
                issued_at="2026-11-01T13:00:00+00:00",
                observed_at="2026-11-01T12:00:00+00:00",
            )
        )


def test_post_target_availability_is_future_leakage() -> None:
    with pytest.raises(ValueError, match="availability_at after target_at"):
        assert_no_future_leakage(
            _pair(
                target_at="2026-11-01T12:00:00+00:00",
                availability_at="2026-11-01T12:30:00+00:00",
                observed_at="2026-11-01T13:00:00+00:00",
                issued_at="2026-11-01T12:30:00+00:00",
            )
        )


def test_missing_not_coerced_to_zero_and_holdout_mae() -> None:
    pairs = [
        _pair(target_at="2026-11-01T12:00:00+00:00", forecast_value=40.0, observed_value=42.0),
        _pair(
            target_at="2026-11-02T12:00:00+00:00",
            issued_at="2026-11-02T00:00:00+00:00",
            availability_at="2026-11-02T00:00:00+00:00",
            observed_at="2026-11-02T12:05:00+00:00",
            forecast_value=None,
            observed_value=50.0,
        ),
        _pair(
            target_at="2026-11-03T12:00:00+00:00",
            issued_at="2026-11-03T00:00:00+00:00",
            availability_at="2026-11-03T00:00:00+00:00",
            observed_at="2026-11-03T12:05:00+00:00",
            forecast_value=60.0,
            observed_value=50.0,
        ),
        _pair(
            # Future leakage pair should be rejected, not scored.
            target_at="2026-11-04T12:00:00+00:00",
            issued_at="2026-11-04T13:00:00+00:00",
            availability_at="2026-11-04T13:00:00+00:00",
            observed_at="2026-11-04T12:05:00+00:00",
            forecast_value=10.0,
            observed_value=10.0,
        ),
    ]
    metrics = evaluate_pairs(pairs, holdout_after="2026-11-01T23:59:59+00:00")
    assert metrics.missing_forecast_count == 1
    assert metrics.future_leakage_rejected == 1
    assert metrics.evaluated_count == 1
    assert metrics.mae == 10.0
    assert metrics.bias == 10.0
