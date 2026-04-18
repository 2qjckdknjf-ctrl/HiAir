# HiAir QA Run 002 Report

Date: 2026-04-07  
Scope: backend security/subscription hardening alignment before beta manual pass

## What was validated in this run

- Profile ownership guardrails are enforced for risk/symptom/dashboard/recommendations/notifications flows.
- Notifications API is user-scoped (no dispatch/read access for another user).
- Subscription webhook idempotency path is implemented and covered in smoke script logic.
- Migration path for existing DB environments is prepared (`001` + `002` + ordered bootstrap).
- QA runbook/checklists are aligned with current backend auth model (`Bearer` + ownership + subscription gating).

## Automated checks executed

- Python compile check: `python3 -m compileall app scripts` -> passed.
- IDE lint diagnostics on changed backend/docs files -> no issues.
- DB bootstrap migrations: `.venv/bin/python scripts/init_db.py` -> passed (`2` migrations).
- Backend smoke flow: `.venv/bin/python scripts/smoke_db_flow.py` -> passed.
- Beta preflight with authenticated checks:
  - `.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000` -> passed.

## Notes and residual risks

- Runtime checks emitted `InsecureKeyLengthWarning` for JWT HMAC key length in local environment.
- Action: set `JWT_SECRET` to a random secret with at least 32 bytes in staging/production.
- Full mobile device matrix QA is still pending and must be executed via `docs/qa-checklist.md`.

## Exit criteria status

- Backend hardening implementation: complete.
- Documentation and test procedure alignment: complete.
- Runtime smoke/preflight on provisioned env: complete.
