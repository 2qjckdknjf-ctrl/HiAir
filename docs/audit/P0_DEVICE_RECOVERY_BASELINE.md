# P0 Device Recovery — Baseline Checkpoint

**Date:** 2026-07-23  
**Branch:** `fix/p0-device-recovery` (from `main` @ `5ffb6f2`)  
**Rollback point:** `5ffb6f2da9fae29639fec50ec07a458f7005a3b9`  
**Production code SHA:** `02439521f3c56eb7ebe0fe6119d0be2179138293` (docs tip `5ffb6f2` is docs-only after deploy)  
**Production health:** `https://api.hiair.io/api/health` → `deploy_git_sha=0243952…`  
**TestFlight:** build **109**, marketing `0.1.0`, `VALID` / `READY_FOR_BETA_TESTING`  
**Working tree at branch create:** clean of tracked changes (untracked `.tools/` / docs noise ignored)

## Known device failures (owner-reported on TF 109)

| # | Flow | Symptom |
|---|------|---------|
| 1 | Startup | App does not refresh data on launch |
| 2 | Geolocation | Location not determined / not applied |
| 3 | HealthKit | Connect Health hangs |
| 4 | Premium | Plan does not activate / entitlement not unlocked |

## Code audit hypotheses (pre-fix)

| Flow | Top root cause | Evidence |
|------|----------------|----------|
| Startup | Dashboard `.task` awaits location before fetch; empty `profileId` without location; no `scenePhase` refresh; duplicate parallel bootstraps | `DashboardView.swift`, `RootTabView.swift`, `AppSession.swift` |
| Geolocation | On `.notDetermined` bootstrap returns immediately; no auto-fetch after Allow | `AppSession.bootstrapLocationFromDevice`, `LocationService.locationManagerDidChangeAuthorization` |
| HealthKit | Connect UI awaits 50–75 sequential HK queries with no timeout after auth | `WearableConsentView.connect`, `HealthKitService.syncHealthIntelligence` |
| Premium | ASC empty catalog still possible; verify `finish()` gated on `is_premium`; OAuth path skips `refreshEntitlement` | `SubscriptionService`, `AppSession` NC observer |

## Expected integrated flow (certification target)

Fresh install → session → profile → location → Health → Dashboard → StoreKit purchase → entitlement → Premium unlock → restart → re-login → restore.

## Safety rules in force

- No Premium bypass, no fake location/health/StoreKit.
- Separate commits per subsystem.
- Device PASS requires physical iPhone evidence (simulator ≠ PASS).
- Rollback: `git checkout 5ffb6f2` / reset branch to this SHA.

## Commit plan

1. `fix: restore deterministic startup refresh`
2. `fix: restore end-to-end geolocation bootstrap`
3. `fix: prevent healthkit connection hangs`
4. `fix: restore storekit premium activation`
5. `test: certify device recovery flows`
6. `docs: document p0 device recovery evidence`
