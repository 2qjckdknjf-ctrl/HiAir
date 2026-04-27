# HiAir Phase 5 PostgreSQL Runtime + Backend Smoke Report

## Starting State

| Area | Starting status | Evidence |
| ---- | --------------- | -------- |
| Backend tests | GO | Phase 4 final run: `30 passed` |
| PostgreSQL local runtime | BLOCKED_BY_ENV | `pg_isready -h localhost -p 5432`: no response |
| Homebrew PostgreSQL service | BLOCKED_BY_ENV | Phase 4 `brew services start postgresql@16` failed with `launchctl bootstrap ... Input/output error`; Phase 5 showed service `error 2` |
| Docker fallback | BLOCKED_BY_ENV | Docker CLI unavailable |
| Backend DB smoke | BLOCKED_BY_ENV | Could not run DB-backed smoke without Postgres |
| API preflight | BLOCKED_BY_ENV | API server could not be validated without DB runtime |
| Closed Beta | NEAR-GO | Runtime gate was the remaining technical P0 blocker |

## 1. Executive Summary

- Starting blocker: PostgreSQL server was not accepting connections on `localhost:5432`; Docker was unavailable; Homebrew service was unstable.
- Runtime fix attempted: stopped Homebrew service, diagnosed missing Homebrew data directory, created a local-only PostgreSQL cluster under `~/.hiair/postgres-data`, and started it with `LC_ALL=C pg_ctl`.
- PostgreSQL verdict: GO.
- DB smoke verdict: GO.
- API preflight verdict: GO.
- Closed Beta impact: the local backend runtime P0 gate is now closed for local evidence. Closed Beta remains NEAR-GO until Apple, Google Play, Firebase/APNs, legal, and ops gates are completed.

## 2. PostgreSQL Diagnosis

| Check | Result | Status |
| ----- | ------ | ------ |
| `which brew` | `/usr/local/bin/brew` | GO |
| `brew --version` | `Homebrew 5.1.6` | GO |
| `which psql` | `/usr/local/bin/psql` | GO |
| `psql --version` | `psql (PostgreSQL) 16.13 (Homebrew)` | GO |
| `which pg_ctl` | `/usr/local/bin/pg_ctl` | GO |
| `pg_ctl --version` | `pg_ctl (PostgreSQL) 16.13 (Homebrew)` | GO |
| `which initdb` | `/usr/local/bin/initdb` | GO |
| `initdb --version` | `initdb (PostgreSQL) 16.13 (Homebrew)` | GO |
| `which postgres` | `/usr/local/bin/postgres` | GO |
| `postgres --version` | `postgres (PostgreSQL) 16.13 (Homebrew)` | GO |
| `brew list` filtered for Postgres | `postgresql@16` installed | GO |
| `brew services list` filtered for Postgres | `postgresql@16 error 2` before manual fix | BLOCKED_BY_ENV |
| Homebrew plist | Points to `/usr/local/var/postgresql@16` | GO |
| Homebrew data dir | `/usr/local/var/postgresql@16` did not exist | BLOCKED_BY_ENV |
| Homebrew log | `postgres: could not access directory "/usr/local/var/postgresql@16": No such file or directory` | BLOCKED_BY_ENV |
| Port 5432 before fix | No listener | BLOCKED_BY_ENV |

## 3. Runtime Fixes Applied

| Action | Result | Status |
| ------ | ------ | ------ |
| Stop Homebrew service | `brew services stop postgresql@16` succeeded | GO |
| Start Homebrew service | Service started but returned to `error 2`; `pg_isready` still no response | BLOCKED_BY_ENV |
| Inspect service log | Confirmed missing `/usr/local/var/postgresql@16` data dir | GO |
| Create local-only parent dir | `mkdir -p ~/.hiair` completed | GO |
| First manual init | `initdb -D ~/.hiair/postgres-data` failed due invalid locale | FAILED |
| Locale-safe init | `LC_ALL=C initdb -D ~/.hiair/postgres-data` succeeded | GO |
| First manual start | `pg_ctl ... start` failed with locale hint | FAILED |
| Locale-safe manual start | `LC_ALL=C pg_ctl -D ~/.hiair/postgres-data -l ~/.hiair/postgres.log start` succeeded | GO |
| Readiness check | `pg_isready -h localhost -p 5432` returned accepting connections | GO |

## 4. DB/User Setup

| Step | Result | Status |
| ---- | ------ | ------ |
| Create role | `createuser hiair || true` completed safely | GO |
| Create DB | `createdb -O hiair hiair || true` completed safely | GO |
| Set local password | `ALTER USER hiair WITH PASSWORD 'hiair';` completed | GO |
| Grant DB privileges | `GRANT ALL PRIVILEGES ON DATABASE hiair TO hiair;` completed | GO |
| Grant public schema privileges | `GRANT ALL ON SCHEMA public TO hiair;` completed | GO |
| Verify default user | `psql -d hiair -c "SELECT current_database(), current_user;"` returned database `hiair`, user `alex` | GO |
| Verify app URL user | `psql "postgresql://hiair:hiair@localhost:5432/hiair" -c "SELECT current_database(), current_user;"` returned database `hiair`, user `hiair` | GO |

## 5. Backend Smoke Results

| Command | Result | Status |
| ------- | ------ | ------ |
| `pg_isready -h localhost -p 5432` | `localhost:5432 - принимает подключения` | GO |
| `cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh` | Postgres reachable | GO |
| `scripts/init_db.py` via smoke helper | `Database schema initialized (5 migrations).` | GO |
| `scripts/smoke_db_flow.py` via smoke helper | `DB smoke flow passed.` | GO |
| `scripts/retention_cleanup.py --dry-run` via smoke helper | retention cleanup dry-run completed | GO |
| `scripts/check_env_security.py --strict` via smoke helper | environment security check passed | GO |
| `scripts/validate_risk_historical.py` via smoke helper | `passed: True`, `cases: 4/4` | GO |
| Final backend tests | `cd backend && ../.venv/bin/python -m pytest -q` returned `30 passed` | GO |

## 6. API Preflight Results

| Command | Result | Status |
| ------- | ------ | ------ |
| Temporary API start | `../.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000` started successfully | GO |
| Health check | `curl http://127.0.0.1:8000/api/health` returned `{"status":"ok","service":"hiair-backend",...}` | GO |
| `scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"` | All endpoint checks printed `[OK]`; ownership guard passed; `Preflight passed.` | GO |
| API shutdown | Temporary uvicorn process was killed after preflight | GO |

## 7. Remaining Blockers

| Blocker | Type | Exact next action |
| ------- | ---- | ----------------- |
| Homebrew service data dir remains missing | BLOCKED_BY_ENV | Keep using `LC_ALL=C pg_ctl -D ~/.hiair/postgres-data -l ~/.hiair/postgres.log start`, or initialize `/usr/local/var/postgresql@16` separately if Homebrew service management is required |
| Docker fallback unavailable | BLOCKED_BY_ENV | Install Docker Desktop only if the owner wants containerized Postgres instead of manual `pg_ctl` |
| TestFlight | BLOCKED_EXTERNAL | Provide Apple Developer/App Store Connect signing and upload access |
| Google Play Internal | BLOCKED_EXTERNAL | Provide Play Console access, signing decision, tester list, and Data Safety answers |
| Push live E2E | BLOCKED_EXTERNAL | Configure Firebase/APNs/FCM and run physical-device QA |
| Store/legal/ops | BLOCKED_EXTERNAL / LEGAL_SIGNOFF_REQUIRED | Complete legal signoff, privacy labels/Data Safety, beta owner, on-call owner, support channel, and WAF/rate limiting evidence |

## 8. Final Verdict

| Target | Verdict | Why |
| ------ | ------- | --- |
| PostgreSQL local runtime | GO | Manual `LC_ALL=C pg_ctl` runtime is accepting connections on `localhost:5432` |
| DB migrations/init | GO | `init_db.py` applied 5 migrations through smoke helper |
| Backend smoke | GO | `smoke_db_flow.py` passed through smoke helper |
| Retention dry-run | GO | `retention_cleanup.py --dry-run` completed |
| API health | GO | temporary API returned `status=ok` |
| API preflight | GO | `beta_preflight.py` passed all checks |
| Closed Beta | NEAR-GO | Backend runtime P0 is closed locally; remaining blockers are external/manual launch gates |

## 9. Commands That Reproduce the Green Path

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
cd backend
PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh
```

Temporary API/preflight:

```bash
cd backend
set -a
source .env.local
set +a
../.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

In another terminal:

```bash
cd backend
set -a
source .env.local
set +a
curl http://127.0.0.1:8000/api/health
../.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"
```
