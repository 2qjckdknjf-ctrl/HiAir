"""Privacy-minimized product analytics event contract (no location/health payloads)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

# Roadmap events from weekly AI reconciliation (2026-11-26/27).
PRODUCT_EVENT_NAMES = frozenset(
    {
        "app_store_click",
        "first_useful_recommendation",
        "repeat_use",
        "retention_window",
        # Existing high-signal mobile events kept compatible:
        "dashboard_loaded",
        "dashboard_retry",
        "action_plan_accepted",
        "activity_plan_followed",
    }
)

FORBIDDEN_PROPERTY_KEYS = frozenset(
    {
        "email",
        "token",
        "user",
        "user_id",
        "profile_id",
        "lat",
        "lon",
        "latitude",
        "longitude",
        "health",
        "heart_rate",
        "steps_raw",
        "sleep_raw",
    }
)

FORBIDDEN_PROPERTY_SUBSTRINGS = (
    "email",
    "token",
    "user",
    "lat",
    "lon",
    "health",
    "diagnos",
)


@dataclass(frozen=True)
class ProductAnalyticsEvent:
    name: str
    properties: dict[str, str]
    consented: bool
    occurred_at: str
    schema_version: str = "hiair-product-v1"


def _is_forbidden_key(key: str) -> bool:
    lowered = key.lower().strip()
    if lowered in FORBIDDEN_PROPERTY_KEYS:
        return True
    return any(part in lowered for part in FORBIDDEN_PROPERTY_SUBSTRINGS)


def sanitize_properties(properties: dict[str, Any] | None) -> dict[str, str]:
    cleaned: dict[str, str] = {}
    for key, value in (properties or {}).items():
        if not isinstance(key, str) or _is_forbidden_key(key):
            continue
        text = str(value).strip()
        if not text or "@" in text:
            continue
        # Block precise coordinates / long numeric dumps.
        if any(ch.isdigit() for ch in text) and ("." in text) and len(text) > 8:
            # Allow short enums like "window=7d"; reject GPS-like values.
            if text.count(".") == 1 and all(part.replace("-", "").isdigit() for part in text.split(".")):
                continue
        cleaned[key] = text[:64]
    return cleaned


def validate_product_event(
    name: str,
    *,
    properties: dict[str, Any] | None = None,
    consented: bool,
    occurred_at: str | None = None,
) -> ProductAnalyticsEvent:
    if name not in PRODUCT_EVENT_NAMES:
        raise ValueError(f"unknown product analytics event: {name}")
    if not consented:
        raise PermissionError("product analytics requires explicit consent")
    stamp = occurred_at or datetime.now(timezone.utc).isoformat()
    # Reject future-dated events beyond a small clock-skew window (5 minutes).
    try:
        parsed = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        skew = (parsed - datetime.now(timezone.utc)).total_seconds()
        if skew > 300:
            raise ValueError("product analytics event timestamp is in the future")
    except ValueError as exc:
        if "future" in str(exc):
            raise
        raise ValueError("product analytics event timestamp must be ISO-8601") from exc
    return ProductAnalyticsEvent(
        name=name,
        properties=sanitize_properties(properties),
        consented=True,
        occurred_at=stamp,
    )


def dedupe_key(event: ProductAnalyticsEvent, *, subject_hash: str) -> str:
    """Stable dedupe key using a non-reversible subject hash (never raw user id)."""
    if not subject_hash or len(subject_hash) < 8:
        raise ValueError("subject_hash must be a non-reversible hash (>=8 chars)")
    props = ",".join(f"{k}={event.properties[k]}" for k in sorted(event.properties))
    day = event.occurred_at[:10]
    return f"{event.schema_version}:{event.name}:{subject_hash}:{day}:{props}"
