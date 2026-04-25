# HiAir Backend (FastAPI)

## Run locally

1. Create virtual environment and install dependencies:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

For staging-like setup, start from:

```bash
cp .env.staging.example .env
```

Generate secure secrets and paste them into `.env`:

```bash
.venv/bin/python scripts/generate_env_secrets.py
```

2. Start API:

```bash
.venv/bin/uvicorn app.main:app --reload
```

3. Check endpoints:

- `GET http://127.0.0.1:8000/api/health`
- `GET http://127.0.0.1:8000/api/environment/snapshot?lat=41.39&lon=2.17&source=mock`
- `POST http://127.0.0.1:8000/api/risk/estimate`
- `GET http://127.0.0.1:8000/api/risk/thresholds`
- `POST http://127.0.0.1:8000/api/auth/signup`
- `POST http://127.0.0.1:8000/api/auth/login`
- `POST http://127.0.0.1:8000/api/profiles` (requires `Authorization: Bearer <token>`)
- `GET http://127.0.0.1:8000/api/profiles` (requires `Authorization: Bearer <token>`)
- `GET http://127.0.0.1:8000/api/privacy/export` (requires auth)
- `POST http://127.0.0.1:8000/api/privacy/delete-account` (requires auth + confirmation)
- `POST http://127.0.0.1:8000/api/symptoms/log` (requires auth; `profile_id` ownership is validated)
- `GET http://127.0.0.1:8000/api/settings` (requires `Authorization: Bearer <token>`)
- `PUT http://127.0.0.1:8000/api/settings` (requires `Authorization: Bearer <token>`)
- `GET http://127.0.0.1:8000/api/risk/history?profile_id=<id>` (requires auth; ownership validated)
- `GET http://127.0.0.1:8000/api/recommendations/daily?profile_id=<id>` (requires auth + active subscription)
- `GET http://127.0.0.1:8000/api/air/current-risk?profileId=<id>` (requires auth)
- `GET http://127.0.0.1:8000/api/air/day-plan?profileId=<id>` (requires auth)
- `GET http://127.0.0.1:8000/api/air/recommendations?profileId=<id>` (requires auth)
- `POST http://127.0.0.1:8000/api/air/recompute-risk`
- `POST http://127.0.0.1:8000/api/alerts/evaluate`
- `GET http://127.0.0.1:8000/api/dashboard/overview?persona=adult&lat=41.39&lon=2.17` (requires auth)
  - optional `profile_id=<id>` enables DB-backed personalization/history persistence.
- `GET http://127.0.0.1:8000/api/planner/daily?persona=adult&lat=41.39&lon=2.17&hours=12`
- `GET http://127.0.0.1:8000/api/validation/risk/historical`
- `GET http://127.0.0.1:8000/api/observability/metrics`
- `GET http://127.0.0.1:8000/api/observability/ai-summary?hours=24`
- `GET http://127.0.0.1:8000/api/observability/ai-summary-detailed?hours=72`
- `POST http://127.0.0.1:8000/api/notifications/preview` (requires auth; optional `profile_id` ownership validated)
- `POST http://127.0.0.1:8000/api/notifications/device-token` (requires auth; optional `profile_id` ownership validated)
- `POST http://127.0.0.1:8000/api/notifications/dispatch` (requires auth; only own user/profile allowed)
- `GET http://127.0.0.1:8000/api/notifications/provider-health`
- `POST http://127.0.0.1:8000/api/notifications/secrets-refresh` (requires `X-Admin-Token`)
- `GET http://127.0.0.1:8000/api/notifications/secret-store-health`
- `GET http://127.0.0.1:8000/api/notifications/delivery-attempts?limit=100` (requires auth; scoped to current user)
- `GET http://127.0.0.1:8000/api/notifications/credentials-health`
- `POST http://127.0.0.1:8000/api/notifications/credentials-rotate` (requires `X-Admin-Token`)
- `GET http://127.0.0.1:8000/api/subscriptions/plans`
- `GET http://127.0.0.1:8000/api/subscriptions/me` (requires auth)
- `POST http://127.0.0.1:8000/api/subscriptions/activate` (requires auth)
- `POST http://127.0.0.1:8000/api/subscriptions/cancel` (requires auth)
- `POST http://127.0.0.1:8000/api/subscriptions/webhook/{provider}` (requires webhook signature)

Dispatch endpoint stores notification events and simulates provider delivery fan-out.

Provider adapter mode is controlled by `NOTIFICATIONS_PROVIDER_MODE`:
- `stub` (default): dry-run adapter delivery
- `live`: uses FCM/APNs adapter HTTP delivery with credential checks

Retry controls:
- `NOTIFICATION_MAX_ATTEMPTS` (default `3`)
- `NOTIFICATION_RETRY_BACKOFF_MS` (default `300`)

Secret rotation controls:
- `NOTIFICATION_SECRET_ROTATION_DAYS` (default `30`)
- `NOTIFICATION_ADMIN_TOKEN` (required for protected staging/production ops endpoints)

Secret source controls:
- `SECRET_SOURCE=env|file|http|vault`
- `SECRET_FILE_PATH=/absolute/path/to/secrets.json` when using `file`
- `SECRET_HTTP_URL=https://...` for external secret backend
- `SECRET_HTTP_TOKEN=...` bearer token for secret backend
- `SECRET_HTTP_TIMEOUT_MS=4000`
- `SECRET_CACHE_TTL_SECONDS=60`
- `VAULT_ADDR=https://vault.example.com`
- `VAULT_TOKEN=...`
- `VAULT_NAMESPACE=...` (optional)
- `VAULT_KV_MOUNT=secret`
- `VAULT_KV_PATH=hiair`

HTTP secret source expects JSON map:

```json
{
  "FCM_PROJECT_ID": "...",
  "FCM_CLIENT_EMAIL": "...",
  "FCM_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----",
  "APNS_TEAM_ID": "...",
  "APNS_KEY_ID": "...",
  "APNS_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----",
  "APNS_TOPIC": "com.example.app"
}
```

Vault secret source expects KV v2 data under:

`/v1/<VAULT_KV_MOUNT>/data/<VAULT_KV_PATH>`

Notification preview body:

```json
{
  "risk": {
    "score": 72,
    "level": "high",
    "recommendations": ["Limit outdoor exposure during peak hours."],
    "components": {
      "env_component": 40,
      "persona_component": 20,
      "symptom_component": 12
    }
  },
  "profile_id": null
}
```

## PostgreSQL schema

Initial schema is in:

- `backend/sql/001_init.sql`
- `backend/sql/002_subscription_and_access_hardening.sql`
- `backend/sql/003_ai_mvp_architecture.sql`
- `backend/sql/004_ai_observability.sql`
- `backend/sql/005_i18n_preferred_language.sql`

Apply manually only when you need step-by-step control:

```bash
for file in sql/*.sql; do psql "$DATABASE_URL" -f "$file"; done
```

Or run bootstrap script:

```bash
.venv/bin/python scripts/init_db.py
```

`init_db.py` applies all SQL files in `backend/sql/` in lexical order.

Without an available PostgreSQL instance, database-backed endpoints return `503`.

## Local DB quickstart (Docker)

From repository root:

```bash
docker compose up -d postgres
```

From `backend/`:

```bash
.venv/bin/python scripts/init_db.py
.venv/bin/python scripts/check_env_security.py --strict
.venv/bin/python scripts/smoke_db_flow.py
.venv/bin/python scripts/validate_risk_historical.py
.venv/bin/python scripts/retention_cleanup.py --dry-run
```

One-command backend gate (without HTTP preflight):

```bash
.venv/bin/python scripts/run_backend_gate.py
```

Apply retention cleanup (non-dry-run):

```bash
.venv/bin/python scripts/retention_cleanup.py
```

Example body for risk estimate:

```json
{
  "persona": "asthma",
  "symptoms": {
    "cough": true,
    "wheeze": true,
    "headache": false,
    "fatigue": true,
    "sleep_quality": 2
  },
  "environment": {
    "temperature_c": 33.0,
    "humidity_percent": 70.0,
    "aqi": 125,
    "pm25": 41.0,
    "ozone": 95.0,
    "source": "mock"
  }
}
```
