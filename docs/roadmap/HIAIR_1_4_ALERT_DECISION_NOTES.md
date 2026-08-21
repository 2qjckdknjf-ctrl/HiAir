# HiAir 1.4 — Alert Decision Engine

**Status:** IN PROGRESS (core decision gate)  
**Branch:** `feat/hiair-1.2-best-time-planner` (stacked)

## Shipped
- Models: `backend/app/models/alert_decision.py`
- Engine: `backend/app/services/alert_decision_engine.py`
- Additive API: `POST /api/alerts/decide`
- Tests: `backend/tests/test_alert_decision_engine.py`

## Decision rules
Suppress when:
- cooldown active
- quiet hours
- duplicate fingerprint
- below personal threshold
- not actionable

Otherwise send with the candidate reason code.

## Not yet
- Wire into production push dispatcher path
- Mobile preference UI for personal thresholds
- Telemetry for suppress rates
