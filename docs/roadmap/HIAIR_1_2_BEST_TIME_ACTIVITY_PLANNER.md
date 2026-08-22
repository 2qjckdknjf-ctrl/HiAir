# HiAir 1.2 — Best Time & Activity Planner

**Status:** DEPLOYED on `api.hiair.io` (`5447279e`) — device QA pending  
**Branch:** `feat/hiair-1.2-best-time-planner`

## Shipped

### Backend
- `GET /api/planner/activities`
- `POST /api/planner/activity-plan`
- Engine: Best / Acceptable / Avoid from real hourly forecast points
- Tests: `test_activity_plan_engine.py`, `test_activity_plan_api.py`

### iOS / Android
- Additive activity card on Daily Planner (no redesign)
- Catalog + plan fetch, 402 premium handling
- RU/EN/ES/IT/FR strings
- Unit decode/parse tests

## Product rules preserved
1. Action Engine decides; AI only explains.
2. No synthetic future hours.
3. Missing air/UV → never claim `best` for outdoor exertion.
4. Premium gate matches extended forecast planner.

## Still open (external)
- [x] Production deploy of 1.1 + 1.2 (`api.hiair.io`)
- [x] Authenticated API smoke (`smoke_feature_surfaces_prod.py` incl. activity-plan 402)
- [ ] Physical-device / TestFlight QA
- [x] Analytics events (`activity_plan_created`, `activity_plan_followed`, `protected_day_event_recorded`)
