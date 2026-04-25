# Local/Staging Beta Smoke

Status: READY_FOR_OWNER. Phase 5 local runtime on this Mac is GO when started with the manual `pg_ctl` path below.

## Environment

Use local-only values. Do not use production secrets.

```bash
cp backend/.env.local.example backend/.env.local
```

Required local variables:

```text
APP_ENV=local
DATABASE_URL=postgresql://hiair:hiair@localhost:5432/hiair
JWT_SECRET=local-dev-change-me-but-long-enough
NOTIFICATION_ADMIN_TOKEN=local-admin-token-change-me
SUBSCRIPTION_WEBHOOK_SECRET=local-webhook-secret-change-me
NOTIFICATIONS_PROVIDER_MODE=stub
SUBSCRIPTION_PROVIDER=stub
RETENTION_DRY_RUN=true
```

## Option A - Local Postgres Without Docker

macOS/Homebrew:

```bash
brew install postgresql@16
brew services start postgresql@16
createuser hiair || true
createdb -O hiair hiair || true
psql -d hiair -c "ALTER USER hiair WITH PASSWORD 'hiair';"
```

If `psql` is not on `PATH`, use:

```bash
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
```

If `brew services start postgresql@16` reports success but `pg_isready` still says no response, inspect the service log:

```bash
brew services list | awk 'tolower($0) ~ /postgres/ {print}'
```

In Phase 5 on Aleksandr's Mac, the Homebrew plist pointed to `/usr/local/var/postgresql@16`, but that data directory did not exist.

## Option A2 - Manual pg_ctl Local-Only Runtime

Use this when Homebrew service management is broken or the Homebrew data directory is missing. This creates a local-only cluster under the user home directory and does not delete or modify existing PostgreSQL data directories.

```bash
brew services stop postgresql@16 || true
mkdir -p ~/.hiair
[ -s ~/.hiair/postgres-data/PG_VERSION ] || LC_ALL=C initdb -D ~/.hiair/postgres-data
LC_ALL=C pg_ctl -D ~/.hiair/postgres-data -l ~/.hiair/postgres.log start
pg_isready -h localhost -p 5432
```

Expected evidence:

```text
localhost:5432 - принимает подключения
```

Stop this local runtime when needed:

```bash
LC_ALL=C pg_ctl -D ~/.hiair/postgres-data stop
```

## Option B - Docker Compose

When Docker is available:

```bash
docker compose -f backend/docker-compose.local.yml up -d postgres
```

Local compose service:

```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: hiair
      POSTGRES_PASSWORD: hiair
      POSTGRES_DB: hiair
    ports:
      - "5432:5432"
```

## Run Smoke

From repo root:

```bash
chmod +x backend/scripts/run_local_beta_smoke.sh
cd backend
PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh
```

The script prints:

- `DONE` for completed checks.
- `BLOCKED_BY_ENV` for missing Postgres/API runtime.
- `FAILED` for command failures that need code/env fixes.

## Expected Green Path

- `pg_isready -h localhost -p 5432`: accepting connections
- `check_env_security.py --strict`: DONE
- `init_db.py`: DONE
- `smoke_db_flow.py`: DONE
- `retention_cleanup.py --dry-run`: DONE
- `validate_risk_historical.py`: DONE
- `beta_preflight.py`: DONE when API server is running
