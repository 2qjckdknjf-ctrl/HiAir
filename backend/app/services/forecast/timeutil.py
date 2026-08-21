"""Timezone helpers for forecast points. Always use the location zone, never server UTC as local."""

from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


def resolve_zone(timezone_name: str | None, fallback: str = "UTC") -> ZoneInfo:
    name = (timezone_name or "").strip() or fallback
    try:
        return ZoneInfo(name)
    except ZoneInfoNotFoundError:
        return ZoneInfo(fallback)


def attach_timezone(local_naive_iso: str, timezone_name: str) -> str:
    """Attach an IANA zone to a provider local timestamp and emit offset-aware ISO-8601."""
    raw = local_naive_iso.strip()
    if not raw:
        raise ValueError("empty timestamp")
    # Provider times are typically 'YYYY-MM-DDTHH:MM' or 'YYYY-MM-DDTHH:MM:SS'
    if raw.endswith("Z") or "+" in raw[10:] or raw.count("-") >= 3:
        parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        if parsed.tzinfo is not None:
            return parsed.isoformat()
        aware = parsed.replace(tzinfo=resolve_zone(timezone_name))
        return aware.isoformat()
    parsed = datetime.fromisoformat(raw)
    aware = parsed.replace(tzinfo=resolve_zone(timezone_name))
    return aware.isoformat()


def now_iso(timezone_name: str = "UTC") -> str:
    return datetime.now(resolve_zone(timezone_name)).isoformat()


def utcnow_iso() -> str:
    return datetime.now(resolve_zone("UTC")).isoformat()
