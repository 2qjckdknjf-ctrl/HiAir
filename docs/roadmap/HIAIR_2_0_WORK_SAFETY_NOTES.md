# HiAir 2.0 — Work / B2B Safety CORE

**Status:** IN PROGRESS (backend + Settings UI; prod `GET /api/work/site-risk` on `408ec1c3`)  
**Branch:** `feat/hiair-1.2-best-time-planner`  
**Depends on:** HiAir 1.1 Forecast Truth (honest environmental metrics)

## Goal

Occupational heat safety layer for worksites and B2B integrations — clearly separated from consumer “feels hot” language and personal risk scoring.

## Backend (this slice)

- `GET /api/work/site-risk?lat=&lon=&workload=moderate&acclimatized=true` — auth required
- Engine: `backend/app/services/work_safety_engine.py`
- Models: `backend/app/models/work_safety.py`
- Workloads: `light`, `moderate`, `heavy`, `very_heavy`
- Work/rest tables: NIOSH-*inspired* heuristic v0 (scaffold only)

## Mobile (additive)

- iOS/Android Settings: occupational site-risk card (separate from consumer Dashboard heat)
- Workload picker + work/rest summary; explicit proxy disclaimer when `heat_index_proxy_only`

## Product rules

1. **Consumer Heat Index ≠ occupational WBGT.** Never label apparent temperature / feels-like as WBGT.
2. When WBGT is unavailable → `wbgtC=null`, `reasonCodes` includes `wbgt_unavailable`.
3. Heat index may be used only with explicit `heat_index_proxy_only` caution — not as regulatory WBGT.
4. Missing metrics stay null; never zero-filled or inferred.
5. Not medical advice, not OSHA/NIOSH compliance certification.

## Still open

- [ ] WBGT provider / on-site sensor ingestion
- [ ] Site registry and multi-site dashboards
- [ ] Crew scheduling integrations
- [ ] B2B admin API keys and org tenancy
- [x] Production smoke on `api.hiair.io` (`GET /api/work/site-risk` in feature smoke)


## WBGT estimate (2026-08-25)
- When instrument WBGT is absent, `wbgt_estimate.estimate_outdoor_wbgt_c` derives outdoor WBGT from T/RH/wind/shortwave.
- Reason codes: `wbgt_estimated_from_meteo`, `not_instrument_wbgt`.
- Never presented as measured occupational WBGT.
