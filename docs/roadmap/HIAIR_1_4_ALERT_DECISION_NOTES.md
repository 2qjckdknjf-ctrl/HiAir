# HiAir 1.4 — Alert Decision Engine

**Status:** IN PROGRESS (core decision gate + suppress telemetry + delivery cooldown on `820b3b6b`)  
**Branch:** `feat/hiair-1.2-best-time-planner` (stacked)

## Shipped
- Models: `backend/app/models/alert_decision.py`
- Engine: `backend/app/services/alert_decision_engine.py`
- Additive API: `POST /api/alerts/decide`
- Tests: `backend/tests/test_alert_decision_engine.py`
- `alert_orchestrator.evaluate_alert` now runs the decision gate before send (quiet hours / dedupe / actionable / personal `alert_threshold`)
- In-memory suppress telemetry via `observability.record_alert_decision` (exposed in `/api/observability/metrics`)
- Profile alert cooldown from latest `alert_events.sent_at` (default 60 minutes)

## Decision rules
Suppress when:
- cooldown active
- quiet hours
- duplicate fingerprint
- below personal threshold
- not actionable

Otherwise send with the candidate reason code.

## Not yet
- Richer per-alert-type cooldown tuning
