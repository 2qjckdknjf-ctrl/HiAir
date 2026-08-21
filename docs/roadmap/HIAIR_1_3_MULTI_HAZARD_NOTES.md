# HiAir 1.3 — Multi-Hazard Intelligence

**Status:** IN PROGRESS (backend + additive mobile UI)  
**Branch:** `feat/hiair-1.2-best-time-planner`  
**Depends on:** HiAir 1.1 Forecast Truth (never invent environmental metrics)

## Goal

Expand from heat + air quality into a modular personal environmental safety layer with regional hazard modules (UV, pollen, smoke, dust, official alerts).

## Backend (this slice)

- `GET /api/air/hazards?profileId=` — additive surface; no premium gate
- Engine: `backend/app/services/hazard_engine.py`
- Models: `backend/app/models/hazard.py`
- Hazard modules: heat, air, UV (from real `EnvironmentalInput`); pollen, smoke, dust return `unavailable` / `provider_not_configured` until providers exist
- Aggregation uses **available hazards only**; never synthesizes missing metrics

## Mobile (additive)

- iOS/Android Dashboard hazards card after air metrics
- Shows overall level + available hazard chips only; unavailable stay honest

## Product rules

1. Deterministic hazard scoring; AI may explain, not invent measurements.
2. Missing UV or air metrics → honest `unavailable`, not zero-filled or inferred values.
3. `GET /api/air/current-risk` remains unchanged.

## Still open

- [ ] Pollen / smoke / dust provider integrations
- [ ] Regional hazard configuration (USA, Southern Europe, GCC, Egypt)
- [ ] NO2 and official alert feeds where data quality allows
- [ ] Production smoke on `api.hiair.io`
- [ ] Merge Personal Environmental Risk with existing risk engine output
