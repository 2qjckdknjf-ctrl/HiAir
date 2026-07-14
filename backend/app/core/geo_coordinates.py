"""Geographic coordinate validation for profile home locations."""

from __future__ import annotations


def validate_home_coordinates(home_lat: float, home_lon: float) -> None:
    if home_lat < -90 or home_lat > 90:
        raise ValueError("home_lat must be between -90 and 90")
    if home_lon < -180 or home_lon > 180:
        raise ValueError("home_lon must be between -180 and 180")
    if home_lat == 0.0 and home_lon == 0.0:
        raise ValueError("home coordinates cannot be null island (0,0)")


def coordinates_are_valid(home_lat: float, home_lon: float) -> bool:
    try:
        validate_home_coordinates(home_lat, home_lon)
    except ValueError:
        return False
    return True
