"""Pollen/smoke providers — never invent values; secondary only fills null fields."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Protocol

import httpx

from app.core.settings import settings


@dataclass(frozen=True)
class PollenSmokeReading:
    pollen_grains_m3: float | None
    wildfire_pm10: float | None
    pollen_source: str | None = None
    smoke_source: str | None = None


class PollenSmokeProvider(Protocol):
    name: str

    def fetch(self, lat: float, lon: float) -> PollenSmokeReading: ...


def merge_pollen_smoke_readings(
    primary: PollenSmokeReading,
    secondary: PollenSmokeReading | None,
) -> PollenSmokeReading:
    """Fill null primary fields from secondary only — never overwrite real values."""
    if secondary is None:
        return primary
    pollen = primary.pollen_grains_m3
    pollen_source = primary.pollen_source
    if pollen is None and secondary.pollen_grains_m3 is not None:
        pollen = secondary.pollen_grains_m3
        pollen_source = secondary.pollen_source
    smoke = primary.wildfire_pm10
    smoke_source = primary.smoke_source
    if smoke is None and secondary.wildfire_pm10 is not None:
        smoke = secondary.wildfire_pm10
        smoke_source = secondary.smoke_source
    return PollenSmokeReading(
        pollen_grains_m3=pollen,
        wildfire_pm10=smoke,
        pollen_source=pollen_source,
        smoke_source=smoke_source,
    )


def _optional_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _max_pollen_grains(current: dict[str, Any]) -> float | None:
    species = (
        "alder_pollen",
        "birch_pollen",
        "grass_pollen",
        "mugwort_pollen",
        "olive_pollen",
        "ragweed_pollen",
    )
    values = [_optional_float(current.get(name)) for name in species]
    present = [value for value in values if value is not None]
    if not present:
        return None
    return max(present)


class OpenMeteoCamsPollenSmokeProvider:
    """Primary CAMS-backed Open-Meteo air-quality pollen + wildfire PM10."""

    name = "openmeteo_cams"

    def fetch(self, lat: float, lon: float) -> PollenSmokeReading:
        url = "https://air-quality-api.open-meteo.com/v1/air-quality"
        params = {
            "latitude": lat,
            "longitude": lon,
            "current": (
                "pm10_wildfires,"
                "alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,"
                "olive_pollen,ragweed_pollen"
            ),
            "timezone": "auto",
        }
        with httpx.Client(timeout=10.0) as client:
            response = client.get(url, params=params)
            response.raise_for_status()
            payload = response.json()
        current = payload.get("current") or {}
        pollen = _max_pollen_grains(current)
        smoke = _optional_float(current.get("pm10_wildfires"))
        return PollenSmokeReading(
            pollen_grains_m3=pollen,
            wildfire_pm10=smoke,
            pollen_source="openmeteo_cams_pollen" if pollen is not None else None,
            smoke_source="openmeteo_pm10_wildfires" if smoke is not None else None,
        )


class AmbeePollenSmokeProvider:
    """Optional Ambee pollen feed — honest empty when key/coverage missing.

    Never invents values. Smoke stays None unless an explicit wildfire field exists.
    """

    name = "ambee"

    def fetch(self, lat: float, lon: float) -> PollenSmokeReading:
        api_key = (settings.ambee_api_key or "").strip()
        if not api_key:
            return PollenSmokeReading(pollen_grains_m3=None, wildfire_pm10=None)

        url = "https://api.ambeedata.com/latest/pollen/by-lat-lng"
        headers = {"x-api-key": api_key, "Content-type": "application/json"}
        params = {"lat": lat, "lng": lon}
        try:
            with httpx.Client(timeout=10.0) as client:
                response = client.get(url, params=params, headers=headers)
                response.raise_for_status()
                payload = response.json()
        except Exception:
            return PollenSmokeReading(pollen_grains_m3=None, wildfire_pm10=None)

        data = payload.get("data") or []
        if isinstance(data, dict):
            data = [data]
        if not data:
            return PollenSmokeReading(pollen_grains_m3=None, wildfire_pm10=None)

        entry = data[0] if isinstance(data, list) else {}
        counts = entry.get("Count") or entry.get("count") or {}
        candidates = [
            _optional_float(counts.get("grass_pollen")),
            _optional_float(counts.get("tree_pollen")),
            _optional_float(counts.get("weed_pollen")),
            _optional_float(counts.get("Grass Pollen")),
            _optional_float(counts.get("Tree Pollen")),
            _optional_float(counts.get("Weed Pollen")),
        ]
        present = [value for value in candidates if value is not None]
        pollen = max(present) if present else None
        return PollenSmokeReading(
            pollen_grains_m3=pollen,
            wildfire_pm10=None,
            pollen_source="ambee_pollen" if pollen is not None else None,
            smoke_source=None,
        )


def _build_provider(name: str) -> PollenSmokeProvider | None:
    key = (name or "").strip().lower()
    if not key or key in {"none", "off", "disabled"}:
        return None
    if key in {"openmeteo", "openmeteo_cams", "cams"}:
        return OpenMeteoCamsPollenSmokeProvider()
    if key == "ambee":
        return AmbeePollenSmokeProvider()
    return None


def resolve_pollen_smoke(
    lat: float,
    lon: float,
    *,
    primary_seed: PollenSmokeReading | None = None,
) -> PollenSmokeReading:
    """Resolve pollen/smoke via primary (+ optional secondary fill-only)."""
    primary_name = settings.pollen_smoke_primary_provider
    secondary_name = settings.pollen_smoke_secondary_provider

    if primary_seed is not None:
        reading = primary_seed
    else:
        primary = _build_provider(primary_name) or OpenMeteoCamsPollenSmokeProvider()
        try:
            reading = primary.fetch(lat, lon)
        except Exception:
            reading = PollenSmokeReading(pollen_grains_m3=None, wildfire_pm10=None)

    secondary = _build_provider(secondary_name)
    if secondary is None:
        return reading
    if reading.pollen_grains_m3 is not None and reading.wildfire_pm10 is not None:
        return reading
    try:
        secondary_reading = secondary.fetch(lat, lon)
    except Exception:
        return reading
    return merge_pollen_smoke_readings(reading, secondary_reading)
