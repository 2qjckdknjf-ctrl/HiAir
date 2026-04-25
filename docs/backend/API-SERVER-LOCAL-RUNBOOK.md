# API Server Local Runbook

Status: READY_FOR_OWNER

## 1. Install Dependencies

From repo root:

```bash
python3 -m venv .venv
.venv/bin/pip install -r backend/requirements.txt
```

## 2. Prepare Local Env

```bash
cp backend/.env.local.example backend/.env.local
```

Do not paste production secrets into local files.

## 3. Start Postgres

Local Homebrew:

```bash
brew services start postgresql@16
createuser hiair || true
createdb -O hiair hiair || true
psql -d hiair -c "ALTER USER hiair WITH PASSWORD 'hiair';"
```

Manual local-only fallback used successfully in Phase 5:

```bash
brew services stop postgresql@16 || true
mkdir -p ~/.hiair
[ -s ~/.hiair/postgres-data/PG_VERSION ] || LC_ALL=C initdb -D ~/.hiair/postgres-data
LC_ALL=C pg_ctl -D ~/.hiair/postgres-data -l ~/.hiair/postgres.log start
pg_isready -h localhost -p 5432
createuser hiair || true
createdb -O hiair hiair || true
psql -d postgres -c "ALTER USER hiair WITH PASSWORD 'hiair';"
psql -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE hiair TO hiair;"
psql -d hiair -c "GRANT ALL ON SCHEMA public TO hiair;"
```

Docker later:

```bash
docker compose -f backend/docker-compose.local.yml up -d postgres
```

## 4. Apply Migrations

```bash
cd backend
set -a
source .env.local
set +a
../.venv/bin/python scripts/init_db.py
```

## 5. Run API

```bash
cd backend
set -a
source .env.local
set +a
../.venv/bin/python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

## 6. Health Check

```bash
curl http://127.0.0.1:8000/api/health
```

Expected: HTTP 200 with healthy payload.

## 7. Beta Preflight

In another terminal:

```bash
cd backend
set -a
source .env.local
set +a
../.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"
```

## 8. BLOCKED_BY_ENV Cases

- PostgreSQL connection refused: start local Postgres or Docker Compose.
- Homebrew service says started but `pg_isready` fails: check whether `/usr/local/var/postgresql@16` exists; use manual `LC_ALL=C pg_ctl -D ~/.hiair/postgres-data ... start` if the service data directory is missing.
- `initdb: invalid locale settings`: rerun init/start with `LC_ALL=C`.
- `JWT_SECRET is missing`: use `.env.local` or export env values.
- API preflight connection errors: start `uvicorn`.
- Docker command not found: use local Homebrew Postgres option.

## 9. Secret Safety

Only use local/stub credentials for this runbook. Production values belong in the deployment secret manager, not in git or local docs.
