# HiAir 1.6 — Personal Adaptation & Protected Days

**Status:** IN PROGRESS (core backend)  
**Branch:** `feat/hiair-1.1-forecast-truth` (stacked)

## Shipped
- Models: `backend/app/models/personal_adaptation.py`
- Engine: `backend/app/services/personal_adaptation_engine.py`
- Additive API: `GET /api/insights/adaptation?profileId=`
- Tests: `backend/tests/test_personal_adaptation_engine.py`

## Personal baselines
- Windows: `d7`, `d30`
- Metrics: resting HR, HRV, sleep minutes, steps, exercise minutes
- Requires **≥5 daily samples** in the window; otherwise `available=false` and `value=null`
- Never invents HRV, resting HR, or sleep when wearable aggregates are absent

## Protected days
- Counts only **structured events** supplied to the engine (`high_risk_period_avoided`, `workout_moved`, `ventilation_window_used`, `poor_air_exposure_reduced`)
- When no events are stored yet, `protectedDays.available=false` with zero counts

## Medical-safety
- Reason codes are wellness-only; diagnosis/treatment language is filtered
- Snapshot always includes `association_not_causation` — associations are not causation

## API behavior
- Premium gate: `wearable_insights_enabled`
- Without active health consent → empty baselines, honest unavailable state
- With consent but no synced aggregates → empty baselines, `no_wearable_aggregates`

## Not yet
- Persist recommendation-follow / protected-day events
- Mobile UI for Protected Days summary
- Wire baselines into alert thresholds and activity planner weighting
- Production smoke on `api.hiair.io`
