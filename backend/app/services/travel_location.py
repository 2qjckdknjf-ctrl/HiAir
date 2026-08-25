"""Apply active travel-mode location override onto a profile context."""

from __future__ import annotations

from app.models.air import UserProfileContext
import app.services.travel_repository as travel_repository


def apply_travel_location_override(
    user_id: str,
    profile: UserProfileContext,
) -> UserProfileContext:
    """Return profile with home coords replaced by travel place when active.

    Never invents coordinates — only uses an owned saved place. Expired or
    missing travel sessions leave the home profile unchanged.
    """
    session = travel_repository.get_travel_session(user_id)
    if not session.active or session.lat is None or session.lon is None:
        return profile
    updates: dict = {
        "home_lat": session.lat,
        "home_lon": session.lon,
    }
    if session.timezone:
        updates["timezone"] = session.timezone
    if session.placeName:
        updates["location_name"] = session.placeName
    return profile.model_copy(update=updates)
