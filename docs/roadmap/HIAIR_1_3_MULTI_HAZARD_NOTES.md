# HiAir 1.3 — Multi-Hazard Intelligence

**Status:** IN PROGRESS (backend core)  
**Branch:** `feat/hiair-1.1-forecast-truth` (1.3 core landed additively; full release TBD)  
**Depends on:** HiAir 1.1 Forecast Truth (never invent environmental metrics)

## Goal

Expand from heat + air quality into a modular personal environmental safety layer with regional hazard modules (UV, pollen, smoke, dust, official alerts).

## Backend (this slice)

- `GET /api/air/hazards?profileId=` — additive surface; no premium gate
- Engine: `backend/app/services/hazard_engine.py`
- Models: `backend/app/models/hazard.py`
- Hazard modules: heat, air, UV (from real `EnvironmentalInput`); pollen, smoke, dust return `unavailable` / `provider_not_configured` until providers exist
- Aggregation uses **available hazards only**; never synthesizes missing metrics

## Product rules

1. Deterministic hazard scoring; AI may explain, not invent measurements.
2. Missing UV or air metrics → honest `unavailable`, not zero-filled or inferred values.
3. `GET /api/air/current-risk` remains unchanged.

## Still open

- [ ] Pollen / smoke / dust provider integrations
- [ ] Regional hazard configuration (USA, Southern Europe, GCC, Egypt)
- [ ] NO2 and official alert feeds where data quality allows
- [ ] iOS / Android multi-hazard UI
- [ ] Production smoke on `api.hiair.io`
- [ ] Merge Personal Environmental Risk with existing risk engine output
