"""Apply active travel-mode location override onto a profile context."""

from __future__ import annotations

from typing import Any

from app.models.air import UserProfileContext
import app.services.travel_repository as travel_repository


def resolve_timezone_for_coords(lat: float, lon: float) -> str | None:
    """Best-effort IANA timezone from Open-Meteo for coordinates (never invents)."""
    try:
        from app.services.environment_service import _fetch_openmeteo_weather

        weather: dict[str, Any] = _fetch_openmeteo_weather(lat, lon)
        tz = weather.get("timezone")
        if isinstance(tz, str) and tz.strip():
            return tz.strip()
    except Exception:
        return None
    return None


def apply_travel_location_override(
    user_id: str,
    profile: UserProfileContext,
) -> UserProfileContext:
    """Return profile with home coords replaced by travel place when active.

    Never invents coordinates — only uses an owned saved place. Expired or
    missing travel sessions leave the home profile unchanged.

    When the saved place has no timezone, resolve one from travel coordinates
    so quiet hours and briefing dispatch follow the travel location.
    """
    session = travel_repository.get_travel_session(user_id)
    if not session.active or session.lat is None or session.lon is None:
        return profile
    updates: dict = {
        "home_lat": session.lat,
        "home_lon": session.lon,
    }
    timezone = session.timezone
    if not timezone:
        timezone = resolve_timezone_for_coords(session.lat, session.lon)
    if timezone:
        updates["timezone"] = timezone
    if session.placeName:
        updates["location_name"] = session.placeName
    return profile.model_copy(update=updates)
