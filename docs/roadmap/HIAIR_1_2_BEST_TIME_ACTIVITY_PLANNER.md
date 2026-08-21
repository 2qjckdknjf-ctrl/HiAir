# HiAir 1.2 — Best Time & Activity Planner

**Status:** IN PROGRESS (backend core)  
**Branch:** `feat/hiair-1.2-best-time-planner`  
**Depends on:** HiAir 1.1 Forecast Truth integrity rules (never invent future environmental values)

## Goal

Answer: **“When is the best time for me to do this activity?”**

## Backend (this branch)

- `GET /api/planner/activities` — activity catalog
- `POST /api/planner/activity-plan` — Best / Acceptable / Avoid windows from real hourly forecast
- Engine: `backend/app/services/activity_plan_engine.py`
- Models: `backend/app/models/activity_plan.py`

## Product rules

1. Action Engine decides; AI only explains reason codes.
2. No synthetic future hours — reuse Forecast Truth hourly points.
3. Missing air/UV → never claim `best` for outdoor exertion.
4. Premium gate matches planner: `extended_forecast`.

## Still open

- [ ] iOS activity picker UI
- [ ] Android parity UI
- [ ] Analytics events (plan created / followed)
- [ ] Production smoke after 1.1 deploy
- [ ] Localization of reason-code labels
