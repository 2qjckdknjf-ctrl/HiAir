import pytest

from app.services.product_analytics_contract import (
    dedupe_key,
    sanitize_properties,
    validate_product_event,
)


def test_consent_gate_blocks_events() -> None:
    with pytest.raises(PermissionError):
        validate_product_event("app_store_click", consented=False)


def test_unknown_event_rejected() -> None:
    with pytest.raises(ValueError, match="unknown"):
        validate_product_event("chat_started", consented=True)


def test_sanitize_strips_location_and_health() -> None:
    cleaned = sanitize_properties(
        {
            "surface": "web",
            "lat": "41.39",
            "health": "hr=72",
            "email": "a@b.c",
            "window": "7d",
        }
    )
    assert cleaned == {"surface": "web", "window": "7d"}


def test_synthetic_events_end_to_end_and_dedupe() -> None:
    events = []
    for name in (
        "app_store_click",
        "first_useful_recommendation",
        "repeat_use",
        "retention_window",
    ):
        event = validate_product_event(
            name,
            properties={"surface": "ios", "window": "7d"},
            consented=True,
            occurred_at="2026-11-27T10:00:00+00:00",
        )
        events.append(event)
        key = dedupe_key(event, subject_hash="abcd1234ffff")
        assert name in key
    assert len(events) == 4
    assert events[0].schema_version == "hiair-product-v1"


def test_future_timestamp_rejected() -> None:
    with pytest.raises(ValueError, match="future"):
        validate_product_event(
            "repeat_use",
            consented=True,
            occurred_at="2099-01-01T00:00:00+00:00",
        )
