# HiAir Beta Execution Runbook

This runbook is the operational sequence for running closed beta cycles.

## 0) Inputs

- Branch/commit for beta candidate.
- Target backend environment URL.
- Tester lists for iOS and Android.
- Owner for triage and release decisions.

## 1) Preflight (backend)

From `backend/`:

```bash
.venv/bin/python scripts/init_db.py
.venv/bin/python scripts/check_env_security.py --strict
.venv/bin/python scripts/retention_cleanup.py --dry-run
.venv/bin/python scripts/smoke_db_flow.py
.venv/bin/python scripts/validate_risk_historical.py
.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"
```

Optional shortcut for local gate (without HTTP preflight):

```bash
.venv/bin/python scripts/run_backend_gate.py
```

Validate:
- `/api/health`
- `/api/notifications/provider-health`
- `/api/notifications/secret-store-health`
- `/api/observability/metrics`
- authenticated preflight checks for signup/profile/subscription/ownership

If any check fails: stop and fix before beta upload.
For ongoing scheduled retention operations, see `docs/ops-retention-runbook.md`.

## 2) Build candidates

### iOS (TestFlight)

1. Generate project (if needed):
   - `cd mobile/ios && xcodegen`
2. Open project and run smoke on simulator/device.
3. Archive with release configuration.
4. Upload archive to App Store Connect.
5. Add internal testers and build notes.

### Android (Google Play Internal Test)

1. Open `mobile/android` in Android Studio.
2. Sync Gradle and run local smoke.
3. Build signed AAB.
4. Upload to Internal Testing track.
5. Add testers and release notes.

## 3) Test mission for beta users

Ask testers to execute:

1. signup/login flow and app restart session restore
2. dashboard refresh
3. daily planner refresh
4. symptom log submit
5. settings load/save
6. subscription activate/cancel

Collect:
- app version
- device model / OS version
- timestamp / timezone
- screenshot or screen recording

## 4) Triage loop (daily)

- Pull issues from beta channels.
- Classify severity:
  - `P0` crash/data loss
  - `P1` major flow broken
  - `P2` usability/performance
  - `P3` polish
- Assign owner and ETA.
- Track status board:
  - `new` -> `triaged` -> `in_fix` -> `ready_for_retest` -> `closed`

## 5) Go/No-Go gate for next beta drop

Go when all are true:
- no unresolved `P0`
- no unresolved `P1` in core flow
- smoke and historical validation pass on candidate commit
- regression checks passed for fixed areas

## 6) Outputs for each cycle

- Build IDs (iOS/Android)
- Known issues list
- Fixed issues list
- Updated release notes
- Decision: go / hold
