# HiAir Development Handoff for Next Agent

Date: 2026-04-07 (status block updated 2026-06-29, P0-B0)
Owner transfer: current agent -> next development agent

## 0) Live status — first-10-users track (2026-06-29)

Branch `release/mega-sprint-2-first-10-users` (3 commits ahead of `origin/main`, clean fast-forward).

- ✅ **P0 Sprint #1** (`205beed`) — Android live dashboard, no mock content; state machine + auto profile bootstrap.
- ✅ **P0 Sprint #2** (`631fb2e`) — backend live→cached→sample environmental resolver; source labeling on both apps.
- ⏳ **P0-B0 Deploy** — `api.hiair.io` **still on old mock-first build** (verified: `source=sample` → 422). Local deploy **blocked** (no Docker/colima/Rosetta for Cloudflare Containers image build; `gh` x86_64/non-functional). **Path:** push branch → `main` triggers `.github/workflows/backend-deploy-production.yml` (CI builds container + post-deploy smoke). Needs production-push authorization + verified GitHub Actions secrets (CLOUDFLARE_API_TOKEN/ACCOUNT_ID, JWT_SECRET, OPENAI_*, WEATHER_API_PROVIDER=openmeteo, AQI_API_PROVIDER=openmeteo).
- ⏳ **Backend validation (local)**: `compileall` OK, `pytest` 119 passed, `validate_risk_historical` 4/4; `check_env_security --strict` fails only on `JWT_SECRET` absent in shell = EXPECTED LOCAL.
- ⏳ **Latency**: `/api/health` cold ~4.1s, warm 0.24–0.63s (Cloudflare Containers cold start).

**Correct sequence:** Deploy + smoke → Device QA → Push token → Internal Testing / TestFlight. Do NOT start device QA until `api.hiair.io` serves the new build.

## 1) Current state (implemented and verified)

### Backend security and access
- JWT auth implemented (`Authorization: Bearer`) with backward-compatible `X-User-Id`.
- User existence validation added in auth dependency (`app/api/deps.py`), so deleted users cannot continue using old token.
- Profile ownership checks enforced across sensitive endpoints:
  - risk history/estimate,
  - symptoms log,
  - dashboard overview,
  - recommendations daily,
  - notifications preview/device-token/dispatch/delivery-attempts.

### Subscriptions
- Subscription API endpoints implemented:
  - plans, me, activate, cancel.
- Subscription webhook contract implemented:
  - endpoint: `/api/subscriptions/webhook/{provider}`,
  - signature verification via `X-Webhook-Signature`,
  - provider adapter and event normalization,
  - idempotency using `subscription_webhook_events` table.

### Privacy (GDPR/CCPA engineering baseline)
- Data export endpoint: `GET /api/privacy/export`.
- Account deletion endpoint: `POST /api/privacy/delete-account` with explicit confirmation `DELETE`.
- Smoke tests cover delete-account invalidation (login and `/auth/me` return 401 after deletion).

### Ops/security tooling
- Env security checker: `backend/scripts/check_env_security.py` (`--strict` mode available).
- Secret generator: `backend/scripts/generate_env_secrets.py`.
- Backend gate orchestrator: `backend/scripts/run_backend_gate.py`.
- Retention cleanup:
  - script: `backend/scripts/retention_cleanup.py`,
  - dry-run + apply modes,
  - env-driven retention windows.
- Upload evidence tooling:
  - `mobile/scripts/generate_release_manifest.py`
  - output: `docs/release-artifacts-manifest.md`
- Ops scheduler runbook:
  - `docs/ops-retention-runbook.md` (cron + systemd examples).

### QA and docs alignment
- `smoke_db_flow.py` and `beta_preflight.py` updated to current auth/subscription/privacy behavior.
- QA/legal/beta docs updated:
  - `docs/qa-checklist.md`
  - `docs/beta-readiness-checklist.md`
  - `docs/beta-execution-runbook.md`
  - `docs/gdpr-ccpa-wellness-review.md`
  - `docs/qa-run-002-report.md`

## 2) Verified commands (latest run)

From `backend/`:

```bash
.venv/bin/python scripts/init_db.py
.venv/bin/python scripts/smoke_db_flow.py
.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000
.venv/bin/python scripts/retention_cleanup.py --dry-run
python3 -m compileall app scripts
```

All of the above passed in the latest cycle.

## 3) Known residual risks

- Local environment can still show `InsecureKeyLengthWarning` if `JWT_SECRET` is too short or default.
- `check_env_security.py --strict` should be enforced in staging/prod gates.
- Legal text is draft-only; legal sign-off is still required before scale/public launch.

## 4) Priority backlog for next development agent

### P1 - Release execution (human-access dependent)
1. Upload beta artifacts to TestFlight and Google Play Internal Testing.
2. Run full device QA matrix using `docs/qa-checklist.md`.
3. Collect and triage defects with `docs/bug-report-template.md`.

### P1 - Legal finalization
1. Final legal review of:
   - `docs/privacy-policy-draft.md`
   - `docs/terms-of-service-draft.md`
2. Add official controller/contact details and jurisdiction clauses.

### P2 - Subscription provider integration (if approved)
1. Implement concrete provider adapter (e.g. Stripe events/signature parsing).
2. Add integration tests for real provider payload variants.

### P2 - Operational hardening
1. Wire scheduled retention cleanup in staging/prod (cron/systemd).
2. Add monitoring/alerts for cleanup failures and abnormal deletion volumes.
3. Use `docs/ops-handover-checklist.md` before enabling production schedule.

## 5) Suggested immediate first task for next agent

Execute a "beta readiness sweep":
1. Run strict env check:
   - `.venv/bin/python scripts/check_env_security.py --strict`
2. Fix any failing env vars.
3. Re-run smoke + preflight.
4. Produce `qa-run-003` report with exact pass/fail evidence and blockers for store upload.

## 6) Acceptance criteria for handoff completion

- Next agent can run backend checks without re-discovering architecture.
- Next steps are explicit, prioritized, and executable.
- Critical security/privacy context is documented in one place.
