# P0 Runtime Performance & UX Recovery

**Branch:** `fix/p0-runtime-ux-recovery`  
**Baseline device:** TestFlight **118** (physical iPhone — user-reported)  
**Code tip:** after this PR lands, need TF **>118** for device re-measure

## Root causes (proven in code)

| Bug | Root cause |
|-----|------------|
| «Ваш район» forever | `DashboardView.locationLabel` always returned static `dashboard.location` when coords exist. **No reverse geocoding existed** (`CLGeocoder` unused). |
| HealthKit Connect tens of seconds | `refreshAuthorizationState()` treated Connected = `lastSyncAt` / snapshots only, **wiping** post-auth `.connected`. Full `collectTodaySnapshots` is sequential (~20–45s). UI awaited that signal. |
| Premium Free 20–30s | No optimistic unlock; purchase path scanned `Transaction.currentEntitlements` before StoreKit sheet; UI waited on verify + single `/me` with slow passive recovery (8s foreground debounce / txn listener). |

## Changes

1. **Location:** `PlaceGeocodingService` + `AppSession.displayPlaceName` cache; geocode immediately after coords; chip shows locality.
2. **HealthKit:** Persist `authorizationCompleted`; Connected after permission; consent+sync background; Settings/Dashboard stop sync-gating Connected.
3. **Premium:** Optimistic unlock on StoreKit `.verified`; remove pre-purchase entitlement scan; bounded `/me` retries (4×400ms); `RuntimePerformanceProbe` stages.

## Measurements

### Before (TF 118 — physical, user-reported / code-bounded)

| Stage | Before |
|------|--------|
| City chip → real locality | **never** (structural; not a duration) |
| Health Connect → Connected UI | **~20–45s** (sync-gated; collect timeout 45s) |
| Premium unlock after purchase | **~20–30s** (user-reported) |

### After (this branch — lab / unit only)

| Stage | After (lab) | Evidence |
|------|-------------|---------|
| `applyEntitlement(isPremium:true)` | **<1 ms** | `PremiumOptimisticUnlockTests` |
| Connected without sync artifacts | **immediate** when `authorizationCompleted` | `HealthKitConnectedStateTests` |
| Place cache empty → resolve API | geocode async; cache hit skips CLGeocoder | `PlaceGeocodingService` + unit cache API |
| `RuntimePerformanceProbe` unit | duration ≥0 ms recorded | `testRuntimeProbeRecordsDuration` |

### Physical device (required for PASS)

| Stage | Target | Status |
|------|--------|--------|
| Cold launch usable | <2s | **NOT RUN** |
| City resolved | <3s | **NOT RUN** |
| Health Connect UI | permission → Connected immediate | **NOT RUN** |
| Premium unlock | <2s | **NOT RUN** |

Do **not** claim device PASS until TF >118 matrix is measured on a physical iPhone with Console/`RuntimePerformanceProbe` durations.

## Regression

| Check | Result |
|------|--------|
| Backend pytest | PASS (~72% cov) |
| iOS unit (RuntimeUX + HealthKit race + AppSession) | PASS |
| Android assembleDebug + unit | PASS |

## Verdict

**CODE FIXED — WAITING FOR PHYSICAL RETEST on TF >118**
