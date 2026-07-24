# P0 Runtime Performance & UX Recovery

**Branch:** `fix/p0-runtime-ux-recovery`  
**PR:** #34  
**Baseline device:** TestFlight **118** (physical iPhone — user-reported)  
**Code tip:** after this PR lands, need TF **>118** for device re-measure

## Root causes (proven in code)

| Bug | Root cause |
|-----|------------|
| «Ваш район» forever | `DashboardView.locationLabel` always returned static `dashboard.location` when coords exist. **No reverse geocoding existed** (`CLGeocoder` unused). |
| HealthKit Connect tens of seconds | `refreshAuthorizationState()` treated Connected = `lastSyncAt` / snapshots only, **wiping** post-auth `.connected`. Full `collectTodaySnapshots` is sequential (~20–45s). UI awaited that signal. |
| Premium Free 20–30s | No optimistic unlock; purchase path scanned `Transaction.currentEntitlements` before StoreKit sheet; UI waited on verify + single `/me` with slow passive recovery (8s foreground debounce / txn listener). |

## Security / privacy blockers closed (review threads)

| Blocker | Fix |
|---------|-----|
| Health sync before durable consent | Sync/upload only after `saveConsent` succeeds (`hasDurableConsent`); states: `systemAuthorized` → `consentSaving` → `connected` / `consentFailed` |
| Global Health auth flag | Keys `hiair.health.authorizationCompleted.<userId>` + `consentPersisted.<userId>`; `bindAccount` / `clearAccountSession` on login/logout |
| Onboarding hides consent failure | Onboarding shows saving / Connected / failed+Retry; does not advance on consent failure; no sync without durable consent |
| Cross-account city disclosure | `displayPlaceName` not persisted globally; Place presentation cache owner-scoped; logout invalidates |
| Stale reverse-geocode | Coordinate-keyed latest-wins; cancel/replace in-flight; ignore stale generation/account |
| Optimistic Premium | Activating (`premiumActivationPending`) after StoreKit verified; backend confirm clears pending; terminal 4xx rolls back; logout clears |

## Changes (speed preserved)

1. **Location:** `PlaceGeocodingService` latest-wins + account presentation; instant same-account nearby cache; geocode after coords.
2. **HealthKit:** System auth exits UI wait immediately → consent save → Connected → background sync only after durable consent.
3. **Premium:** Activating on StoreKit `.verified`; bounded `/me` retries; terminal reject rollback; account-isolated on logout.
4. **Probe:** `RuntimePerformanceProbe` stages unchanged.

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
| `beginPremiumActivation` | **immediate Activating** | `SessionLogoutIsolationTests` |
| Connected only with durable consent | **gate enforced** | `HealthConsentGateTests` |
| Account B ≠ A's Connected/city | **isolated** | `HealthConsentGateTests` + `SessionLogoutIsolationTests` |
| Place presentation account-scoped | **no cross-account leak** | `PlaceGeocodingServiceTests` |
| `RuntimePerformanceProbe` unit | duration ≥0 ms recorded | `testRuntimeProbeRecordsDuration` |

### Physical device (required for PASS)

| Stage | Target | Status |
|------|--------|--------|
| Cached same-account city | immediate | **NOT RUN** |
| New locality | <3s | **NOT RUN** |
| Health system authorization UI exit | immediate | **NOT RUN** |
| Consent persistence | bounded, visible | **NOT RUN** |
| Premium Activating | immediate | **NOT RUN** |
| Server-confirmed Premium | <2s | **NOT RUN** |

Do **not** claim device PASS until TF >118 matrix is measured on a physical iPhone with Console/`RuntimePerformanceProbe` durations.

## Regression

| Check | Result |
|------|--------|
| Backend pytest | (run in PR validation) |
| iOS unit (consent/account/geocode/premium) | (run in PR validation) |
| Android assemble + unit | (run in PR validation) |
| Final gate | (run in PR validation) |

## Verdict

**CODE FIXED — WAITING FOR PHYSICAL RETEST on TF >118**  
Merge forbidden until High/P1/Medium review findings = 0 and threads resolved after new head.
