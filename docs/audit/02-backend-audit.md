# Backend Audit

## Summary

Backend is a FastAPI service with broad MVP coverage. Pytest passed after the ops-admin-token regression fix. DB-backed smoke and retention dry-run are BLOCKED_BY_ENV on this machine because no local Postgres is running and Docker CLI is unavailable.

## Backend structure found

- Entrypoint: `backend/app/main.py`
- Settings: `backend/app/core/settings.py`
- Routes: `backend/app/api`
- Models: `backend/app/models`
- Services/repositories: `backend/app/services`
- SQL migrations: `backend/sql/001_init.sql` through `backend/sql/005_i18n_preferred_language.sql`
- Scripts: `backend/scripts`
- Tests: `backend/tests`

## Endpoints found

Routes include `auth`, `profiles`, `privacy`, `dashboard`, `planner`, `environment`, `risk`, `thresholds`, `air`, `alerts`, `settings`, `subscriptions`, `symptoms`, `recommendations`, `notifications`, `observability`, `validation`, and `health` under `/api`.

## Data models found

Pydantic models exist for air, dashboard, notifications, planner, privacy, recommendations, risk, settings, subscriptions, thresholds, users, and validation.

## Auth/JWT status

Bearer JWT auth is implemented. Legacy `X-User-Id` auth is disabled by default and rejected in protected envs. Ops/admin routes now fail closed in protected envs if `NOTIFICATION_ADMIN_TOKEN` is missing.

Status: FIXED

## Risk engine status

Risk engines and risk-level compatibility are present, including `medium`/`moderate` compatibility helpers and tests.

Status: DONE

## Recommendations status

Daily recommendations and air recommendations are implemented. Subscription gating exists for daily recommendations.

Status: DONE

## Planner status

`GET /api/planner/daily` exists and uses mock environmental data.

Status: DONE

## Symptom log status

Legacy and air-domain symptom endpoints exist with auth and ownership checks.

Status: DONE

## Settings status

`GET/PUT /api/settings` exist and require auth.

Status: DONE

## Notifications status

Backend notification preview, device token, dispatch, provider health, secret health, credentials health, delivery attempts, and live/stub adapters exist. End-to-end APNs/FCM delivery is not verified.

Status: PARTIAL

## Subscriptions status

Plans/status/activate/cancel/webhook scaffold exists. Real payment provider E2E is not verified.

Status: PARTIAL

## Privacy export status

Authenticated export endpoint exists and is covered by tests.

Status: DONE

## Delete account status

Authenticated delete-account endpoint exists and smoke script includes residual data assertions.

Status: DONE

## Retention cleanup status

Script exists, but dry-run on this machine failed due unavailable Postgres.

Status: BLOCKED_BY_ENV

## Observability status

Request metrics and AI observability endpoints exist and are ops-gated. Metrics are in-process and not a production APM replacement.

Status: PARTIAL

## Tests executed

| Command | Result | Status |
|---|---|---|
| `cd backend && ../.venv/bin/python -m pytest -q` | `30 passed` | DONE |
| `cd backend && ../.venv/bin/python scripts/check_env_security.py --strict` | Failed with missing env in unmanaged local shell | BLOCKED_BY_ENV |
| strict env check with safe test env values | Passed | DONE |
| `cd backend && ../.venv/bin/python scripts/retention_cleanup.py --dry-run` | Failed: local Postgres connection refused | BLOCKED_BY_ENV |
| `cd backend && ../.venv/bin/python scripts/validate_risk_historical.py` | `passed: True`, `4/4` cases | DONE |
| `cd backend && ../.venv/bin/python scripts/beta_preflight.py` | Connection errors because API server not running | BLOCKED_BY_ENV |

## Failures found

- CRITICAL: ops/admin dependency allowed unconfigured admin token to pass in all envs.
- RISK: README listed stale manual migration subset and legacy fallback wording.
- BLOCKED_BY_ENV: local DB smoke unavailable.

## Fixes applied

- `backend/app/api/deps.py`: protected envs now return `503` for ops endpoints if `NOTIFICATION_ADMIN_TOKEN` is missing.
- `backend/tests/test_security_runtime_policies.py`: added regression coverage for fail-closed ops token behavior.
- `backend/scripts/check_env_security.py`: updated warning text to match fail-closed protected-env behavior.
- `backend/README.md`: documented all SQL migrations and removed default legacy-auth wording from endpoint examples.

## Remaining blockers

- BLOCKED_BY_ENV: staging database and running API required for smoke/preflight proof.
- BLOCKED_EXTERNAL: production secrets, APNs/FCM credentials, payment provider credentials.
- RISK: public endpoints need deployment-layer rate limiting/WAF before internet exposure.
