# Phase 4 Runtime Owner Gate Register

Snapshot date: 2026-04-25

| ID | Gate | Current status | Exact command/action | Expected evidence | Status |
| -- | ---- | -------------- | -------------------- | ----------------- | ------ |
| P4-001 | local Postgres installed/running | Phase 5 manual runtime started with `LC_ALL=C pg_ctl` | `pg_isready -h localhost -p 5432` | `localhost:5432 - принимает подключения` | GO |
| P4-002 | DB user/database created | Phase 5 local DB/user created | `createuser hiair || true && createdb -O hiair hiair || true && psql -d postgres -c "ALTER USER hiair WITH PASSWORD 'hiair';"` | `current_database=hiair`, `current_user=hiair` via `DATABASE_URL` | GO |
| P4-003 | migrations/init executed | Phase 5 smoke helper initialized schema | `cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh` | `Database schema initialized (5 migrations).` | GO |
| P4-004 | smoke_db_flow executed | Phase 5 smoke flow passed | `cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh` | `DB smoke flow passed.` | GO |
| P4-005 | retention dry-run executed | Phase 5 dry-run passed | `cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh` | `Retention cleanup completed.` | GO |
| P4-006 | API server running | Phase 5 temporary API health check passed | `cd backend && set -a && source .env.local && set +a && ../.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000` | `curl http://127.0.0.1:8000/api/health` returned `status=ok` | GO |
| P4-007 | beta_preflight executed | Phase 5 beta preflight passed | `cd backend && ../.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"` | all preflight checks printed `[OK]`; `Preflight passed.` | GO |
| P4-008 | iOS archive path verified | `mobile/ios/build/HiAir.xcarchive` found by release manifest | `python3 mobile/scripts/generate_release_manifest.py --strict` | manifest lists iOS archive | GO |
| P4-009 | Android AAB path verified | `mobile/android/app/build/outputs/bundle/release/app-release.aab` found | `python3 mobile/scripts/generate_release_manifest.py --strict` | manifest lists Android AAB | GO |
| P4-010 | Apple owner checklist prepared | Owner packet and Apple guide created | open `docs/release/APPLE-DEVELOPER-APP-STORE-CONNECT-SETUP.md` | Apple/TestFlight steps are executable by owner | GO |
| P4-011 | Google owner checklist prepared | Owner packet and Google guide created | open `docs/release/GOOGLE-PLAY-CONSOLE-INTERNAL-TEST-SETUP.md` | Play Internal steps are executable by owner | GO |
| P4-012 | Firebase/APNs owner checklist prepared | Firebase/APNs guide created | open `docs/release/FIREBASE-APNS-FCM-SETUP.md` | APNs/FCM setup steps are executable by owner | GO |
| P4-013 | Legal owner checklist prepared | Included in owner packet and store/legal packet | open `docs/release/HIAIR-CLOSED-BETA-OWNER-EXECUTION-PACKET.md` and `docs/release/STORE-LEGAL-METADATA-LAUNCH-PACKET.md` | legal/store tasks have named evidence | LEGAL_SIGNOFF_REQUIRED |
| P4-014 | Ops owner checklist prepared | Included in owner packet and ops runbook | open `docs/ops/CLOSED-BETA-OPS-RUNBOOK.md` | beta owner/on-call/support/WAF evidence assigned | BLOCKED_EXTERNAL |

## Runtime Evidence

- `which brew`: `/usr/local/bin/brew`
- `which psql`: `/usr/local/bin/psql`
- `psql --version`: `psql (PostgreSQL) 16.13 (Homebrew)`
- `docker --version`: `command not found`
- `pg_isready -h localhost -p 5432`: `localhost:5432 - нет ответа`
- Phase 4 `brew services start postgresql@16`: failed with `launchctl bootstrap ... Input/output error`
- Phase 5 diagnosis: Homebrew service plist points to missing `/usr/local/var/postgresql@16`; service log says `Run initdb or pg_basebackup to initialize a PostgreSQL data directory.`
- Phase 5 manual runtime: `LC_ALL=C initdb -D ~/.hiair/postgres-data` then `LC_ALL=C pg_ctl -D ~/.hiair/postgres-data -l ~/.hiair/postgres.log start`
- Phase 5 `backend/scripts/run_local_beta_smoke.sh`: Postgres reachable, migrations/init DONE, smoke_db_flow DONE, retention dry-run DONE, env strict DONE, historical risk validation DONE
- Phase 5 API preflight: temporary `uvicorn` health returned `status=ok`; `beta_preflight.py` passed

## Final Verification Evidence

| Area | Command | Result | Status |
| ---- | ------- | ------ | ------ |
| Backend tests | `cd backend && ../.venv/bin/python -m pytest -q` | `30 passed` | GO |
| Backend smoke helper | `cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh` | Postgres reachable; migrations, smoke, retention, env strict, historical risk passed | GO |
| API preflight | temporary `uvicorn`; `scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"` | Health returned `status=ok`; preflight passed | GO |
| iOS simulator | `cd mobile/ios && xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO` | `** BUILD SUCCEEDED **` | GO |
| Android release | `cd mobile/android && ./gradlew assembleDebug assembleRelease bundleRelease lint` | `BUILD SUCCESSFUL` | GO |
| Release manifest | `python3 mobile/scripts/generate_release_manifest.py --strict` | Android AAB/APK and iOS archive found; iOS IPA missing | PARTIAL |
