# HiAir 1.3 — Pollen & Smoke Provider Research

**Date:** 2026-08-25  
**Status:** INTEGRATED (Open-Meteo / CAMS) with honest coverage gaps

## Decision

Use **Open-Meteo Air Quality API** (CAMS-backed, no API key for non-commercial):

| Signal | Open-Meteo field | Coverage | Notes |
|--------|------------------|----------|-------|
| Pollen | `alder_pollen`, `birch_pollen`, `grass_pollen`, `mugwort_pollen`, `olive_pollen`, `ragweed_pollen` | **Europe (seasonal)** | Outside Europe / off-season → `null` → hazard `unavailable` |
| Smoke | `pm10_wildfires` | Global CAMS when modeled | `null` when no wildfire contribution → hazard `unavailable` if null |

HiAir stores:
- `pollen_grains_m3` = max of available species (grains/m³)
- `wildfire_pm10` = `pm10_wildfires` (µg/m³)

## Alternatives considered

| Provider | Pros | Cons | Verdict |
|----------|------|------|---------|
| Open-Meteo CAMS | Free, already in stack, honest nulls | Pollen Europe-only | **Selected** |
| Ambee pollen | Broader commercial coverage | Paid API key | **Optional secondary** (`POLLEN_SMOKE_SECONDARY_PROVIDER=ambee`, fill-nulls only) |
| NOAA HMS smoke polygons | High-quality NA smoke | GIS ingest complexity, NA-centric | Future enhancement |
| Infer smoke from PM2.5 alone | Always available | False positives (urban pollution ≠ wildfire) | **Rejected** (honesty) |

## Honesty rules

1. Never synthesize pollen/smoke when provider returns null.
2. Dust remains PM10-based and separate from wildfire smoke.
3. Reason codes include `openmeteo_cams_pollen` / `openmeteo_pm10_wildfires`.

## Live probe (2026-08-25)

- Berlin: grass/ragweed pollen present; `pm10_wildfires=0` → smoke **available** (low).
- Los Angeles: pollen null; `pm10_wildfires` null → pollen/smoke **unavailable**.

## Secondary provider wiring (2026-08-25)

- Interface: `app.services.pollen_smoke`
- Primary: Open-Meteo CAMS (always)
- Secondary: Ambee when `AMBEE_API_KEY` set and `POLLEN_SMOKE_SECONDARY_PROVIDER=ambee`
- Merge rule: fill null pollen/smoke fields only — never overwrite CAMS values, never invent
