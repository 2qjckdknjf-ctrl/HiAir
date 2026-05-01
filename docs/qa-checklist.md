# HiAir QA Checklist (Closed Beta)

Use this checklist for manual QA of the MVP flow.

## A. Onboarding

- [ ] App launches to onboarding on fresh install.
- [ ] Persona selection works and persists.
- [ ] Latitude/longitude inputs are accepted and reused by dashboard/planner.
- [ ] Signup/login succeeds and session is restored after app restart.
- [ ] Access token is persisted and reused for API calls.
- [ ] Continue action leads to main tab shell.

## B. Dashboard

- [ ] Refresh action returns current risk level and score.
- [ ] Recommendation text is non-empty.
- [ ] Daily summary and daily actions are visible.
- [ ] Notification text appears when `should_notify=true`.
- [ ] No crash on network failure; error messaging is shown.

## C. Daily Planner

- [ ] Planner loads 12 hourly slots by default.
- [ ] Safe windows are shown when available.
- [ ] Refresh updates values.
- [ ] Planner works with session persona/location.

## D. Symptom Log

- [ ] Profile ID field accepts valid value.
- [ ] Symptom toggles update state.
- [ ] Sleep quality range is constrained to 1..5.
- [ ] Submit stores log successfully (`Saved at ...`).
- [ ] Error state is shown for missing/invalid profile.
- [ ] Access to a foreign `profile_id` is rejected with authorization error.

## E. Settings

- [ ] Authenticated session is required for load/save.
- [ ] Load retrieves server values for:
  - [ ] push alerts
  - [ ] alert threshold
  - [ ] default persona
- [ ] Save persists modified values.
- [ ] Persona update propagates to session behavior where applicable.
- [ ] Morning Briefing settings:
  - [ ] `GET /api/briefings/schedule` is reflected in toggle + time field
  - [ ] `PUT /api/briefings/schedule` persists toggle + time updates
  - [ ] unauthenticated state shows setup hint and does not silently save
- [ ] Subscription section works:
  - [ ] load plans
  - [ ] load my subscription
  - [ ] activate trial/plan
  - [ ] cancel subscription

## F. Notifications

- [ ] Device token registration endpoint accepts token for own profile.
- [ ] Dispatch endpoint returns provider result map for current user only.
- [ ] Delivery attempts endpoint records attempts for current user scope.
- [ ] Provider health and credentials health endpoints respond.
- [ ] Secret store health endpoint reports expected source.

## G. Validation and reliability

- [ ] `scripts/smoke_db_flow.py` passes.
- [ ] `scripts/beta_preflight.py` passes including auth/ownership checks.
- [ ] `scripts/validate_risk_historical.py` passes (all cases).
- [ ] `/api/observability/metrics` shows growing request counters.
- [ ] Structured request logs include `request_id`, path, status, latency.

## H. Regression notes

- [ ] Document any failed item with:
  - step to reproduce,
  - expected result,
  - actual result,
  - screenshot/log reference.

## I. Privacy rights flow

- [ ] `GET /api/privacy/export` returns current user data payload.
- [ ] `POST /api/privacy/delete-account` requires exact `DELETE` confirmation.
- [ ] Deleted account can no longer login (`/api/auth/login` returns 401).

## J. Insights and briefing additions

- [ ] Insights tab shows explicit loading, empty, and error/retry states.
- [ ] Insights tab renders server correlation rows when data exists.
- [ ] `GET /api/insights/personal-patterns` works for the active profile.
- [ ] `scripts/smoke_db_flow.py` includes insights + briefing endpoint checks.
- [ ] `scripts/beta_preflight.py` includes insights + briefing endpoint checks.
