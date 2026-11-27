from app.services import observability
from app.services.provider_reliability import ReliabilitySignal, open_incident


def test_record_provider_reliability_signal_in_metrics() -> None:
    before = observability.snapshot_metrics()["provider_reliability_incidents_opened"]
    observability.record_provider_reliability_signal("stale_aqi", open_incident=True)
    metrics = observability.snapshot_metrics()
    assert metrics["provider_reliability_signals"]["stale_aqi"] >= 1
    assert metrics["provider_reliability_incidents_opened"] == before + 1


def test_open_incident_uses_reliability_stages() -> None:
    incident = open_incident("openmeteo", ReliabilitySignal.PROVIDER_OUTAGE, "obs-1")
    incident.advance("investigate")
    incident.advance("validate_ready")
    incident.record_validation(passed=True, note="ok")
    assert incident.independent_validation_passed is True
