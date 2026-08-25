# HiAir 1.6 — Personal Adaptation & Protected Days

**Status:** IN PROGRESS (backend + Insights UI + event persistence; prod APIs live on `408ec1c3`)  
**Branch:** `feat/hiair-1.2-best-time-planner` (stacked)

## Shipped
- Models: `backend/app/models/personal_adaptation.py`
- Engine: `backend/app/services/personal_adaptation_engine.py`
- Additive API: `GET /api/insights/adaptation?profileId=`
- Event API: `POST /api/insights/protected-day-events`
- Persistence: `022_protected_day_events.sql` (applied on prod Supabase)
- Tests: `test_personal_adaptation_engine.py`, `test_protected_day_events_api.py`
- iOS/Android Insights: adaptation card (402 → existing paywall)

## Personal baselines
- Windows: `d7`, `d30`
- Metrics: resting HR, HRV, sleep minutes, steps, exercise minutes
- Requires **≥5 daily samples** in the window; otherwise `available=false` and `value=null`
- Never invents HRV, resting HR, or sleep when wearable aggregates are absent

## Protected days
- Counts only **structured events** (`high_risk_period_avoided`, `workout_moved`, `ventilation_window_used`, `poor_air_exposure_reduced`)
- Events persist per user/profile and feed adaptation snapshot
- When no events are stored yet, `protectedDays.available=false` with zero counts

## Medical-safety
- Reason codes are wellness-only; diagnosis/treatment language is filtered
- Snapshot always includes `association_not_causation` — associations are not causation

## API behavior
- Premium gate: `wearable_insights_enabled`
- Without active health consent → empty baselines, honest unavailable state
- With consent but no synced aggregates → empty baselines, `no_wearable_aggregates`

## Not yet
- [x] Wire baselines into alert thresholds (one-step more sensitive when recovery strain vs personal baselines)
- [x] Wire sleep-vs-7d-baseline into personal load (feeds activity planner weighting)
- Travel-mode place override remains under 1.5

## Mobile follow-through (user-initiated)
- Planner "Mark workout moved" records `workout_moved` via `POST /api/insights/protected-day-events` (iOS + Android)
- Planner "Mark ventilation used" records `ventilation_window_used` when ventilation windows are shown
- Android planner saved-place picker mirrors iOS
- Dashboard protected-day card (high/very_high risk): `poor_air_exposure_reduced`, `high_risk_period_avoided` (iOS + Android)
