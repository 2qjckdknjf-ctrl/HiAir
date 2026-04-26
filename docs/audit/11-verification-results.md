# Verification Results

Snapshot date: 2026-04-25

| Area | Command | Result | Evidence | Status |
|---|---|---|---|---|
| Repo | `git status --short` | Dirty tree with pre-existing changes plus this audit/fix pass | Local git output | DONE |
| Backend deps | `python3 -m venv .venv && .venv/bin/pip install -r backend/requirements.txt` | Requirements available | pip output showed satisfied packages | DONE |
| Backend tests | `cd backend && ../.venv/bin/python -m pytest -q` | `30 passed` | Local pytest output | DONE |
| Backend env strict local | `cd backend && ../.venv/bin/python scripts/check_env_security.py --strict` | Failed due missing unmanaged local env | JWT missing, admin/webhook retention warnings | BLOCKED_BY_ENV |
| Backend env strict safe test | `JWT_SECRET=... NOTIFICATION_ADMIN_TOKEN=... SUBSCRIPTION_WEBHOOK_SECRET=... ../.venv/bin/python scripts/check_env_security.py --strict` | Passed | Environment security check passed | DONE |
| Backend retention | `cd backend && ../.venv/bin/python scripts/retention_cleanup.py --dry-run` | Failed | Local Postgres connection refused | BLOCKED_BY_ENV |
| Backend historical risk | `cd backend && ../.venv/bin/python scripts/validate_risk_historical.py` | Passed | `passed: True`, `4/4` cases | DONE |
| Backend preflight | `cd backend && ../.venv/bin/python scripts/beta_preflight.py` | Failed | API server not running; connection errors | BLOCKED_BY_ENV |
| Docker | `docker --version` | Failed | command not found | BLOCKED_BY_ENV |
| Android | `cd mobile/android && ./gradlew assembleDebug assembleRelease lint` | Passed | `BUILD SUCCESSFUL` | DONE |
| iOS scheme | `cd mobile/ios && xcodebuild -list -project HiAir.xcodeproj` | Passed | Scheme `HiAir` found | DONE |
| iOS build | `cd mobile/ios && xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO` | Passed after fix | `BUILD SUCCEEDED` | FIXED |
| Release manifest | `python3 mobile/scripts/generate_release_manifest.py --strict` | Partial | Android AAB/APK and iOS archive found; iOS IPA missing | PARTIAL |
| Mobile observability | `rg "/observability" mobile` | No matches | User-facing mobile clients no longer call ops endpoints | FIXED |
| iOS Phase 2 build | `cd mobile/ios && xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO` | Passed | `BUILD SUCCEEDED` | DONE |
| Android Phase 2 build/lint | `cd mobile/android && ./gradlew assembleDebug assembleRelease lint` | Passed | `BUILD SUCCESSFUL` | DONE |
| Backend Phase 2 tests | `cd backend && ../.venv/bin/python -m pytest -q` | `30 passed` | Local pytest output | DONE |
| Backend Phase 2 env safe test | strict env check with safe env values | Passed | Environment security check passed | DONE |
| Backend Phase 3 tests | `cd backend && ../.venv/bin/python -m pytest -q` | `30 passed` | Local pytest output | DONE |
| Backend Phase 3 unmanaged env strict | `cd backend && ../.venv/bin/python scripts/check_env_security.py --strict` | Failed because shell env lacks `JWT_SECRET` and local secrets | Expected unmanaged local env blocker | BLOCKED_BY_ENV |
| Backend Phase 3 historical risk | `cd backend && ../.venv/bin/python scripts/validate_risk_historical.py` | `passed: True`, `4/4` cases | Local script output | DONE |
| Backend Phase 3 local smoke helper | `cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh` | Env strict and historical validation passed; Postgres/API unavailable | `BLOCKED_BY_ENV` for DB/API runtime | BLOCKED_BY_ENV |
| iOS Phase 3 scheme/build | `xcodebuild -list` and simulator build | Passed | Scheme `HiAir`; build exit 0 | DONE |
| Android Phase 3 build/lint | `./gradlew assembleDebug assembleRelease lint` | `BUILD SUCCESSFUL` | Local Gradle output | DONE |
| Android Phase 3 bundle | `./gradlew bundleRelease` | `BUILD SUCCESSFUL` | `app-release.aab` generated | DONE |
| Release manifest Phase 3 | `python3 mobile/scripts/generate_release_manifest.py --strict` | Partial | Android AAB/APK and iOS archive found; iOS IPA missing | PARTIAL |
| Backend Phase 4 tests | `cd backend && ../.venv/bin/python -m pytest -q` | `30 passed` | Local pytest output | DONE |
| Backend Phase 4 local smoke helper | `cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh` | Env strict and historical validation passed; Postgres/API unavailable | `localhost:5432` connection refused; API not running | BLOCKED_BY_ENV |
| Backend Phase 4 tool probe | `which brew && which psql && psql --version && docker --version` | Homebrew and PostgreSQL client available; Docker missing | `psql (PostgreSQL) 16.13`; `docker: command not found` | PARTIAL |
| Backend Phase 4 Postgres start | `pg_isready`; `brew services start postgresql@16` | Postgres did not start | `launchctl bootstrap ... Input/output error`; `localhost:5432 - нет ответа` | BLOCKED_BY_ENV |
| iOS Phase 4 simulator build | `cd mobile/ios && xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO` | Passed | `** BUILD SUCCEEDED **` | DONE |
| Android Phase 4 build/lint/bundle | `cd mobile/android && ./gradlew assembleDebug assembleRelease bundleRelease lint` | Passed | `BUILD SUCCESSFUL` | DONE |
| Release manifest Phase 4 | `python3 mobile/scripts/generate_release_manifest.py --strict` | Partial | Android AAB/APK and iOS archive found; iOS IPA missing | PARTIAL |
| Phase 5 PostgreSQL diagnosis | `which pg_ctl`; `which initdb`; `brew services list`; service log read | PostgreSQL 16 binaries installed; Homebrew service data dir missing | `/usr/local/var/postgresql@16` missing; log says `Run initdb` | DONE |
| Phase 5 PostgreSQL manual runtime | `LC_ALL=C initdb -D ~/.hiair/postgres-data`; `LC_ALL=C pg_ctl -D ~/.hiair/postgres-data -l ~/.hiair/postgres.log start` | Postgres started locally | `pg_isready`: accepting connections | DONE |
| Phase 5 DB/user setup | `createuser hiair`; `createdb -O hiair hiair`; grants; URL connect test | Local DB/user reachable | `current_database=hiair`, `current_user=hiair` | DONE |
| Phase 5 backend smoke | `cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh` | DB runtime path passed | migrations/init, `smoke_db_flow`, retention dry-run, env strict, historical risk all DONE | DONE |
| Phase 5 API health/preflight | temporary `uvicorn` on `127.0.0.1:8000`; `beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"` | Passed | health returned `status=ok`; preflight printed all `[OK]` and `Preflight passed.` | DONE |
| Phase 5 backend tests | `cd backend && ../.venv/bin/python -m pytest -q` | `30 passed` | Local pytest output | DONE |
| Phase 6 RC1 Postgres readiness | `pg_isready -h localhost -p 5432` | Accepting connections | Local manual PostgreSQL runtime is available | DONE |
| Phase 6 RC1 backend tests | `cd backend && ../.venv/bin/python -m pytest -q` | `30 passed` | Local pytest output | DONE |
| Phase 6 RC1 backend smoke | `cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh` | Passed | migrations/init, smoke_db_flow, retention dry-run, env strict, historical risk validation all DONE | DONE |
| Phase 6 RC1 API health/preflight | temporary `uvicorn`; `beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"` | Passed | health returned `status=ok`; preflight printed all `[OK]` and `Preflight passed.` | DONE |
| Phase 6 RC1 iOS simulator | `cd mobile/ios && xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO` | Passed | `** BUILD SUCCEEDED **` | DONE |
| Phase 6 RC1 Android clean build/lint/bundle | `cd mobile/android && ./gradlew clean assembleDebug assembleRelease bundleRelease lint` | Passed | `BUILD SUCCESSFUL` | DONE |
| Phase 6 RC1 release manifest | `python3 mobile/scripts/generate_release_manifest.py --strict` | Passed | Android AAB/APK and iOS archive/IPA found | DONE |
| Phase 6 RC1 version check | searched backend/iOS/Android version fields | Found backend `0.1.0`, iOS `com.hiair.app` `0.1.0` build `1`, Android `com.hiair` `0.1.0` code `1` | DONE |
| Phase 18 Postgres | `pg_isready -h localhost -p 5432` | accepting connections | DONE |
| Phase 18 backend tests | `cd backend && ../.venv/bin/python -m pytest -q` | `36 passed` | DONE |
| Phase 18 backend smoke | `PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh` | DB smoke path OK; preflight skipped when API down, then API+preflight run separately | DONE |
| Phase 18 API preflight | `uvicorn` + `scripts/beta_preflight.py` | `Preflight passed.` | DONE |
| Phase 18 iOS simulator | `xcodebuild … Debug … iphonesimulator … CODE_SIGNING_ALLOWED=NO` | `** BUILD SUCCEEDED **` | DONE |
| Phase 18 Android full gate | `./gradlew clean assembleDebug assembleRelease bundleRelease lint` | `BUILD SUCCESSFUL` | DONE |
| Phase 18 manifest RC | `python3 mobile/scripts/generate_release_manifest.py --rc` | manifest written; strict mandatory set documented | DONE |
| Phase 20 pytest | `cd backend && ../.venv/bin/python -m pytest -q` | `36 passed` (post `datetime.now(UTC)` mock fix) | DONE |
| Phase 20 Android compile | `./gradlew :app:compileDebugKotlin` | `BUILD SUCCESSFUL` | DONE |
| Phase 20 iOS simulator | `xcodebuild … iphonesimulator …` | `** BUILD SUCCEEDED **` | DONE |
| Phase 21 smoke script | `bash -n backend/scripts/run_local_beta_smoke.sh` | exit 0 | DONE |
| Phase 21 Android assembleDebug | `./gradlew :app:assembleDebug` | success | DONE |
| Phase 22 Android | `./gradlew :app:assembleDebug :app:lintDebug` | `BUILD SUCCESSFUL` | DONE |
| Phase 22 Android release | `./gradlew :app:assembleRelease :app:bundleRelease` | success (no local `google-services.json`) | DONE |

## Not verified

- iOS real-device build/archive/upload.
- Android signed AAB upload.
- APNs/FCM live delivery.
- Android live FCM token generation with real Firebase config.
- Stripe/payment provider E2E.
- Production monitoring/on-call execution.
- Legal and store portal approvals.
