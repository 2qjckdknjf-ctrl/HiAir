# P0 Runtime Performance & UX Recovery

**Branch:** `fix/p0-runtime-ux-recovery` (PR #34)  
**Final head:** `cac4b12` → merged `cda6722` on `main`  
**Baseline device:** TestFlight **118** (physical iPhone — user-reported)  
**Retest build:** TestFlight **127** VALID → «Первый» (`IN_BETA_TESTING`)

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
| **Untracked Dashboard sync** | Dashboard uses only `startBackgroundHealthSync` (single `syncInFlight` + `syncGeneration`); no unstructured `Task` + direct sync |
| **Consent cleared too late** | `revokeLocalConsentImmediately` clears durable consent + cancels sync **before** any remote await; remote failure → `remoteRevokePending` / `revokeFailed` with sync still blocked |
| **Premium rollback without userId** | Rollback notifications carry `userId`; `AppSession.shouldApplyRollbackNotification` ignores foreign/unattributed rollbacks |

## Key fix commits

| Commit | Change |
|--------|--------|
| `93e4182` | Route dashboard health sync through cancellable coordinator |
| `0936a2a` | Revoke local health consent before remote operations |
| `f8f45d5` | Cover revoke/delete/account-switch sync races |
| `879546e` | Attribute premium rollback notifications to account |
| `cac4b12` | Isolate place cache tests + rollback gate coverage |
| `cda6722` | Merge PR #34 into `main` |

## CI / review (merge gate)

| Item | Result |
|------|--------|
| Final PR head | `cac4b12` |
| Unresolved threads | 0 |
| ios-build (push) | PASS [30156640948](https://github.com/2qjckdknjf-ctrl/HiAir/actions/runs/30156640948) |
| ios-build (PR) | PASS [30156642010](https://github.com/2qjckdknjf-ctrl/HiAir/actions/runs/30156642010) |
| Security Reviewer | PASS |
| Find vulnerabilities | PASS |
| Xcode Cloud Archive | PASS |
| Backend/Android CI | path-filtered (no backend/android delta on final head); local Android previously PASS |

## TestFlight

| Item | Result |
|------|--------|
| Version | 0.1.0 |
| Build | **127** |
| ASC id | `3fc99d09-b232-4bce-a7a1-1f72449f9bbb` |
| Status | VALID / `IN_BETA_TESTING` |
| Group | «Первый» |
| Merge SHA | `cda6722` |

## Physical device

| Stage | Target | Status |
|------|--------|--------|
| Cached same-account city | immediate | **NOT RUN** |
| New locality | <3s | **NOT RUN** |
| Health system authorization UI exit | immediate | **NOT RUN** |
| Consent persistence | bounded, visible | **NOT RUN** |
| Premium Activating | immediate | **NOT RUN** |
| Server-confirmed Premium | <2s | **NOT RUN** |
| Revoke during sync | no upload | **NOT RUN** |

## Verdict

**CODE FIXED — WAITING FOR PHYSICAL RETEST** on TestFlight **127**.
