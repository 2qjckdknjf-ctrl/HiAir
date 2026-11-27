from app.services.anomaly_detector import SourceReading, detect_anomalies, independently_verify
from app.services.provider_reliability import (
    ReliabilitySignal,
    ReliabilityStage,
    classify_provider_reading,
    open_incident,
)


def test_classify_missing_and_false_zero_signals() -> None:
    assert classify_provider_reading(aqi=None, raw_aqi_token="-", age_seconds=10) == ReliabilitySignal.MISSING_API_DATA
    assert (
        classify_provider_reading(aqi=0, raw_aqi_token="unknown", age_seconds=10) == ReliabilitySignal.FALSE_ZERO
    )
    assert classify_provider_reading(aqi=0, raw_aqi_token="0", age_seconds=10) is None
    assert (
        classify_provider_reading(aqi=12, raw_aqi_token="12", age_seconds=9000) == ReliabilitySignal.STALE_AQI
    )


def test_reliability_loop_alert_to_verify() -> None:
    incident = open_incident("openmeteo", ReliabilitySignal.STALE_AQI, "inc-1")
    assert incident.stage == ReliabilityStage.ALERT
    incident.advance("opened_ticket")
    incident.advance("checked_provider_status")
    incident.record_validation(passed=True, note="independent_obs_confirm_stale")
    incident.record_fix("refresh_cache_ttl_tuning")
    incident.record_post_fix_verification(passed=True, note="fresh_reading_ok")
    assert incident.stage == ReliabilityStage.CLOSED
    assert incident.post_fix_verified is True


def test_two_stage_anomaly_distinguishes_source_issues() -> None:
    history = [
        SourceReading("openmeteo", "bcn", f"2026-11-01T{hour:02d}:00:00+00:00", 40 + (hour % 3))
        for hour in range(10)
    ]
    spike = SourceReading("openmeteo", "bcn", "2026-11-01T10:00:00+00:00", 200)
    missing = SourceReading("openmeteo", "bcn", "2026-11-01T11:00:00+00:00", None, source_status="missing")
    candidates = detect_anomalies(history + [spike, missing], min_history=8, z_threshold=3.0)
    reasons = {c.reason for c in candidates}
    assert "source_missing" in reasons
    assert "aqi_zscore" in reasons

    spike_candidate = next(c for c in candidates if c.reason == "aqi_zscore")
    peers = [SourceReading("waqi", "bcn", "2026-11-01T10:00:00+00:00", 45)]
    verdict = independently_verify(spike_candidate, corroborating=peers)
    assert verdict.independently_verified is True

    missing_candidate = next(c for c in candidates if c.reason == "source_missing")
    missing_verdict = independently_verify(missing_candidate, corroborating=[])
    assert missing_verdict.verification_reason == "source_quality_issue_not_pollution"
    assert missing_verdict.false_positive is False
