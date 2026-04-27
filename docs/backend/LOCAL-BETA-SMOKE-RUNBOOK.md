# Local Beta Smoke Runbook

Status: READY_DOCS, local DB still BLOCKED_BY_ENV on the current machine.

## Prerequisites

- Python virtualenv with `backend/requirements.txt` installed.
- PostgreSQL reachable at `DATABASE_URL`.
- No production secrets are required for local smoke.

## Option A - local PostgreSQL

1. Create local database/user:

```bash
createdb hiair
```

2. From repo root:

```bash
cp backend/.env.local.example backend/.env
cd backend
../.venv/bin/python scripts/check_env_security.py --strict
../.venv/bin/python scripts/init_db.py
../.venv/bin/python scripts/retention_cleanup.py --dry-run
../.venv/bin/python scripts/smoke_db_flow.py
../.venv/bin/python scripts/validate_risk_historical.py
```

## Option B - Docker Compose when Docker is available

From repo root:

```bash
docker compose up -d postgres
cp backend/.env.local.example backend/.env
cd backend
../.venv/bin/python scripts/run_local_beta_smoke.sh
```

## HTTP preflight

In terminal 1:

```bash
cd backend
../.venv/bin/uvicorn app.main:app --reload
```

In terminal 2:

```bash
cd backend
../.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"
```

## Current machine result

- `docker --version`: BLOCKED_BY_ENV, command not found.
- `retention_cleanup.py --dry-run`: BLOCKED_BY_ENV, local Postgres connection refused.
- `beta_preflight.py`: BLOCKED_BY_ENV when API is not running.
