# QA Checklist — Wearable & Activity Intelligence v1

## iOS

- [ ] Simulator without Health data — app loads, dashboard shows "not connected"
- [ ] Onboarding skip health step — completes normally
- [ ] Onboarding connect — consent saved, sync attempted
- [ ] Device with Apple Health steps/HR — dashboard shows counts
- [ ] Apple Watch data flows via Health app aggregation
- [ ] Permission denied — denied state + settings link
- [ ] Revoke permission in iOS Settings — app continues, degraded card
- [ ] Delete health data in Settings — summaries removed server-side
- [ ] Offline sync failure — sync failed state, app usable
- [ ] Reinstall — no crash without prior consent
- [ ] Subscription/login unaffected

## Android

- [ ] Device without Health Connect — unavailable message
- [ ] Health Connect installed — connect flow
- [ ] Permissions granted — daily sync + dashboard card
- [ ] Permissions denied — not connected state
- [ ] Delete health data — API success
- [ ] Dashboard works without health permissions

## Backend

- [ ] POST consent without auth → 401
- [ ] POST daily-summary without consent → 403
- [ ] Invalid steps (200k) → 422
- [ ] GET /today returns personalLoad when data exists
- [ ] DELETE /data clears summaries

## Risk Engine

- [ ] High heat + high steps increases personalLoad
- [ ] No health data → score 0, no risk penalty
- [ ] Explanations contain no medical diagnosis wording

## Regression

- [ ] Auth login/logout
- [ ] Air current-risk still works
- [ ] Privacy export includes wearable section
- [ ] Account delete removes wearable data
