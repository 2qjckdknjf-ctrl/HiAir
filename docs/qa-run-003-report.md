# HiAir QA Run 003 Report

Date: 2026-04-07  
Scope: CI-hardening pass for backend security and retention controls

## Objectives

- Ensure backend CI includes strict environment security validation.
- Ensure operational retention cleanup is exercised in CI prechecks.
- Re-validate smoke flow under strict-like env values (webhook secret enabled).

## Changes validated

- Updated workflow: `.github/workflows/backend-ci.yml`
  - added secure CI env variables for strict checks,
  - added `scripts/check_env_security.py --strict`,
  - added `scripts/retention_cleanup.py --dry-run`,
  - kept schema bootstrap + smoke flow,
  - added `scripts/validate_risk_historical.py`.
- Updated `scripts/smoke_db_flow.py`:
  - webhook calls are now HMAC-signed when `SUBSCRIPTION_WEBHOOK_SECRET` is set.

## Verification evidence

Executed locally from `backend/` with CI-like env values:

1. `scripts/check_env_security.py --strict` -> passed.
2. `scripts/init_db.py` -> passed.
3. `scripts/retention_cleanup.py --dry-run` -> passed.
4. `scripts/smoke_db_flow.py` -> passed.
5. `scripts/validate_risk_historical.py` -> passed (`4/4`).

## Regression encountered and fixed

- Initial CI-like run failed at `/api/subscriptions/webhook/stub` with `401 Invalid webhook signature`.
- Root cause: smoke test webhook requests were unsigned while webhook secret was set.
- Fix: smoke script now sends `X-Webhook-Signature` (HMAC-SHA256) for webhook payload.

## Current status

- Backend CI gate now covers env-security and retention prechecks.
- Security+retention controls are compatible with smoke validation.
- Remaining launch blockers are outside code (store upload + device QA + legal sign-off).
