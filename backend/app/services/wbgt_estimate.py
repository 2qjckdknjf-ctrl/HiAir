"""Outdoor WBGT estimate from standard meteorological fields.

Honest labeling: this is **not** instrument WBGT. It approximates outdoor WBGT
from dry-bulb, RH, wind, and shortwave radiation using:
  - Stull (2011) wet-bulb approximation
  - a simplified black-globe temperature response to solar load
  - the standard outdoor mix 0.7 Tw + 0.2 Tg + 0.1 Ta

Use only when a measured WBGT sensor feed is unavailable. Callers must surface
``wbgt_estimated_from_meteo`` / ``not_instrument_wbgt`` reason codes.
"""

from __future__ import annotations

import math


def stull_wet_bulb_c(temperature_c: float, relative_humidity_pct: float) -> float:
    """Stull 2011 empirical wet-bulb (°C). RH in 0–100."""
    rh = min(100.0, max(0.01, relative_humidity_pct))
    t = temperature_c
    return (
        t * math.atan(0.151977 * math.sqrt(rh + 8.313659))
        + math.atan(t + rh)
        - math.atan(rh - 1.676331)
        + 0.00391838 * rh**1.5 * math.atan(0.023101 * rh)
        - 4.686035
    )


def approximate_globe_temperature_c(
    temperature_c: float,
    *,
    shortwave_wm2: float,
    wind_speed_ms: float,
) -> float:
    """Simplified outdoor black-globe temperature (°C).

    Solar heating raises Tg; wind cools it toward air temperature. Coefficients
    are engineering approximations for meteo-derived WBGT scaffolding — not a
    Liljegren instrument digital twin.
    """
    solar = max(0.0, shortwave_wm2)
    wind = max(0.1, wind_speed_ms)
    solar_lift = 0.017 * solar / math.sqrt(wind)
    return temperature_c + solar_lift


def estimate_outdoor_wbgt_c(
    temperature_c: float,
    relative_humidity_pct: float,
    *,
    wind_speed_ms: float | None = None,
    shortwave_wm2: float | None = None,
) -> float | None:
    """Return estimated outdoor WBGT (°C), or None if inputs are incomplete."""
    if relative_humidity_pct < 0 or relative_humidity_pct > 100:
        return None
    wind = 0.5 if wind_speed_ms is None else max(0.0, wind_speed_ms)
    solar = 0.0 if shortwave_wm2 is None else max(0.0, shortwave_wm2)
    tw = stull_wet_bulb_c(temperature_c, relative_humidity_pct)
    tg = approximate_globe_temperature_c(
        temperature_c,
        shortwave_wm2=solar,
        wind_speed_ms=wind,
    )
    return round(0.7 * tw + 0.2 * tg + 0.1 * temperature_c, 2)
