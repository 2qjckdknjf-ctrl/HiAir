"""Two-stage AQI/source anomaly research prototype (sandbox; no Risk Engine writes)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from statistics import mean, pstdev


@dataclass(frozen=True)
class SourceReading:
    provider: str
    location_key: str
    observed_at: str
    aqi: int | None
    source_status: str = "ok"  # ok | missing | stale | outage


@dataclass(frozen=True)
class AnomalyCandidate:
    provider: str
    location_key: str
    observed_at: str
    aqi: int | None
    reason: str
    z_score: float | None = None


@dataclass(frozen=True)
class AnomalyVerdict:
    candidate: AnomalyCandidate
    independently_verified: bool
    verification_reason: str
    false_positive: bool


def _parse_ts(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def detect_anomalies(
    readings: list[SourceReading],
    *,
    z_threshold: float = 3.0,
    min_history: int = 8,
) -> list[AnomalyCandidate]:
    """Stage 1: flag unusual AQI/source behavior. Missing/stale are not pollution spikes."""
    candidates: list[AnomalyCandidate] = []
    by_key: dict[tuple[str, str], list[SourceReading]] = {}
    for reading in readings:
        by_key.setdefault((reading.provider, reading.location_key), []).append(reading)

    for (provider, location_key), series in by_key.items():
        ordered = sorted(series, key=lambda item: _parse_ts(item.observed_at))
        for item in ordered:
            if item.source_status in {"missing", "stale", "outage"}:
                candidates.append(
                    AnomalyCandidate(
                        provider=provider,
                        location_key=location_key,
                        observed_at=item.observed_at,
                        aqi=item.aqi,
                        reason=f"source_{item.source_status}",
                    )
                )
                continue
            if item.aqi is None:
                candidates.append(
                    AnomalyCandidate(
                        provider=provider,
                        location_key=location_key,
                        observed_at=item.observed_at,
                        aqi=None,
                        reason="aqi_missing",
                    )
                )
                continue
            prior = [
                reading.aqi
                for reading in ordered
                if reading.aqi is not None
                and reading.source_status == "ok"
                and _parse_ts(reading.observed_at) < _parse_ts(item.observed_at)
            ]
            if len(prior) < min_history:
                continue
            mu = mean(prior)
            sigma = pstdev(prior)
            if sigma <= 0:
                continue
            z_score = (item.aqi - mu) / sigma
            if abs(z_score) >= z_threshold:
                candidates.append(
                    AnomalyCandidate(
                        provider=provider,
                        location_key=location_key,
                        observed_at=item.observed_at,
                        aqi=item.aqi,
                        reason="aqi_zscore",
                        z_score=round(z_score, 3),
                    )
                )
    return candidates


def independently_verify(
    candidate: AnomalyCandidate,
    *,
    corroborating: list[SourceReading],
    deterministic_max_aqi: int = 500,
) -> AnomalyVerdict:
    """Stage 2: verify with timestamped peer observations + deterministic bounds."""
    if candidate.reason.startswith("source_") or candidate.reason == "aqi_missing":
        return AnomalyVerdict(
            candidate=candidate,
            independently_verified=True,
            verification_reason="source_quality_issue_not_pollution",
            false_positive=False,
        )
    if candidate.aqi is None:
        return AnomalyVerdict(
            candidate=candidate,
            independently_verified=True,
            verification_reason="missing_aqi",
            false_positive=False,
        )
    if candidate.aqi < 0 or candidate.aqi > deterministic_max_aqi:
        return AnomalyVerdict(
            candidate=candidate,
            independently_verified=True,
            verification_reason="deterministic_bound_violation",
            false_positive=False,
        )

    peers = [
        reading
        for reading in corroborating
        if reading.location_key == candidate.location_key
        and reading.provider != candidate.provider
        and reading.aqi is not None
        and reading.source_status == "ok"
        and abs((_parse_ts(reading.observed_at) - _parse_ts(candidate.observed_at)).total_seconds()) <= 3600
    ]
    if not peers:
        return AnomalyVerdict(
            candidate=candidate,
            independently_verified=False,
            verification_reason="no_independent_corroboration",
            false_positive=True,
        )
    peer_mean = mean(peer.aqi for peer in peers if peer.aqi is not None)
    if abs(candidate.aqi - peer_mean) < 25:
        return AnomalyVerdict(
            candidate=candidate,
            independently_verified=False,
            verification_reason="peers_near_candidate_likely_false_positive",
            false_positive=True,
        )
    return AnomalyVerdict(
        candidate=candidate,
        independently_verified=True,
        verification_reason="peer_providers_disagree",
        false_positive=False,
    )
