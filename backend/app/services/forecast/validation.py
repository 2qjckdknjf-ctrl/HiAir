"""Historical forecast-as-issued vs observation validation (no future leakage)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from statistics import mean
from typing import Iterable, Sequence


@dataclass(frozen=True)
class ForecastObservationPair:
    """One forecast issued at ``issued_at`` for ``target_at``, later observed."""

    location_key: str
    provider: str
    provider_version: str
    metric: str
    issued_at: str
    target_at: str
    forecast_value: float | None
    observed_at: str
    observed_value: float | None
    availability_at: str


@dataclass(frozen=True)
class ValidationMetrics:
    pair_count: int
    evaluated_count: int
    missing_forecast_count: int
    missing_observation_count: int
    stale_skipped_count: int
    future_leakage_rejected: int
    mae: float | None
    bias: float | None


def _parse_ts(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def assert_no_future_leakage(pair: ForecastObservationPair) -> None:
    """Forecast must be as-issued before the target time being scored."""
    issued = _parse_ts(pair.issued_at)
    available = _parse_ts(pair.availability_at)
    observed = _parse_ts(pair.observed_at)
    target = _parse_ts(pair.target_at)
    if available > observed:
        raise ValueError("future leakage: availability_at after observed_at")
    if available > target:
        raise ValueError("future leakage: availability_at after target_at")
    if issued > observed:
        raise ValueError("future leakage: issued_at after observed_at")
    if issued > target:
        raise ValueError("future leakage: issued_at after target_at")


def evaluate_pairs(
    pairs: Sequence[ForecastObservationPair],
    *,
    holdout_after: str | None = None,
    max_issue_to_target_hours: float | None = 72.0,
) -> ValidationMetrics:
    """Chronological holdout evaluation with honest missing/stale handling.

    Missing forecast or observation values are counted, not coerced to zero.
    Pairs with issue→target horizon beyond ``max_issue_to_target_hours`` are
    treated as stale for this validator and skipped.
    """
    holdout_cut = _parse_ts(holdout_after) if holdout_after else None
    errors: list[float] = []
    signed: list[float] = []
    missing_forecast = 0
    missing_observation = 0
    stale_skipped = 0
    future_rejected = 0
    evaluated = 0

    for pair in pairs:
        if holdout_cut is not None and _parse_ts(pair.target_at) <= holdout_cut:
            continue
        try:
            assert_no_future_leakage(pair)
        except ValueError:
            future_rejected += 1
            continue
        horizon_h = (_parse_ts(pair.target_at) - _parse_ts(pair.issued_at)).total_seconds() / 3600.0
        if max_issue_to_target_hours is not None and horizon_h > max_issue_to_target_hours:
            stale_skipped += 1
            continue
        if pair.forecast_value is None:
            missing_forecast += 1
            continue
        if pair.observed_value is None:
            missing_observation += 1
            continue
        delta = float(pair.forecast_value) - float(pair.observed_value)
        errors.append(abs(delta))
        signed.append(delta)
        evaluated += 1

    return ValidationMetrics(
        pair_count=len(pairs),
        evaluated_count=evaluated,
        missing_forecast_count=missing_forecast,
        missing_observation_count=missing_observation,
        stale_skipped_count=stale_skipped,
        future_leakage_rejected=future_rejected,
        mae=round(mean(errors), 4) if errors else None,
        bias=round(mean(signed), 4) if signed else None,
    )


def group_by_provider(pairs: Iterable[ForecastObservationPair]) -> dict[str, list[ForecastObservationPair]]:
    grouped: dict[str, list[ForecastObservationPair]] = {}
    for pair in pairs:
        key = f"{pair.provider}:{pair.provider_version}:{pair.location_key}"
        grouped.setdefault(key, []).append(pair)
    return grouped
