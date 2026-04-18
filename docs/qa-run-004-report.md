# HiAir QA Run 004 Report

Date: 2026-04-07  
Scope: backend gate automation + fresh mobile build validation

## What was done

- Added one-command backend gate orchestrator:
  - `backend/scripts/run_backend_gate.py`
- Updated CI workflow to enforce:
  - strict env security check,
  - retention cleanup dry-run,
  - historical validation script.
- Fixed smoke test compatibility with webhook signature enforcement when webhook secret is set.

## Automated checks executed

### Backend (CI-like local run)

- `scripts/check_env_security.py --strict` -> passed with explicit CI-like env values.
- `scripts/init_db.py` -> passed.
- `scripts/retention_cleanup.py --dry-run` -> passed.
- `scripts/smoke_db_flow.py` -> passed.
- `scripts/validate_risk_historical.py` -> passed (`4/4`).
- `scripts/run_backend_gate.py --skip-smoke` -> passed.

### Mobile builds (fresh local validation)

- Android:
  - `./gradlew :app:assembleDebug :app:bundleRelease --no-daemon` -> passed.
- iOS:
  - `xcodebuild -project "HiAir.xcodeproj" -scheme "HiAir" -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build` -> passed.

## Issues found and fixed in this run

- Regression detected: smoke webhook test failed with `401 Invalid webhook signature` under strict-like env.
- Resolution: signed webhook payloads in `scripts/smoke_db_flow.py` via HMAC-SHA256 when `SUBSCRIPTION_WEBHOOK_SECRET` is set.

## Current status

- Backend quality gates are now stricter and reproducible.
- Mobile local builds are green for current code state.
- Remaining launch blockers are operational/legal:
  - store upload access and execution,
  - full device QA matrix,
  - legal finalization of privacy/terms.
