# P0 Device Recovery — Final Report

**Date:** 2026-07-23  
**Branch:** `fix/p0-device-recovery`  
**Base:** `main` @ `5ffb6f2` (production API code `0243952`)  
**Rollback:** `5ffb6f2`  
**Verdict:** **CODE FIXED — WAITING FOR PHYSICAL RETEST**

Physical iPhone certification of TF build >109 is **required** before any stronger verdict. Simulator / unit tests ≠ device E2E PASS.

---

## 1. Executive Summary

Stage 0 engineering was already green. Device product flows failed on TF 109 (startup refresh, geolocation, HealthKit hang, Premium unlock). Code audit found concrete root causes; minimal fixes landed on `fix/p0-device-recovery` with unit tests green. **No physical-device PASS claimed.**

---

## 2. Reproduced Failures

| Flow | Build | Device result | Failure point |
|------|-------|---------------|---------------|
| Startup refresh | TF 109 | Owner-reported FAIL | Dashboard awaited location; empty profile without location; no foreground refresh |
| Geolocation | TF 109 | Owner-reported FAIL | Bootstrap returned on `.notDetermined`; no post-Allow retry |
| HealthKit connect | TF 109 | Owner-reported hang | Connect UI awaited 50–75 HK queries + sync |
| Premium | TF 109 | Owner-reported FAIL | Possible ASC empty catalog + `finish()` gated on `is_premium` + OAuth skipped entitlement refresh |

---

## 3. Root Causes

| Flow | Root cause | Evidence |
|------|------------|----------|
| Startup | Parallel bootstraps; dashboard blocked on location; no `scenePhase` refresh | `DashboardView.task`, `RootTabView.task` |
| Geolocation | One-shot bootstrap; onboarding 800ms race; concurrent fetch overwrote continuation | `AppSession.bootstrapLocationFromDevice`, `LocationService` |
| HealthKit | Connect awaited full collect+sync; no auth single-flight; no collect timeout | `WearableConsentView.connect`, `HealthKitService` |
| Premium | `transaction.finish()` only when `is_premium`; restore ignored unfinished; sessionDidChange no `/me` | `SubscriptionService`, `AppSession` |

---

## 4. Startup (code status)

| Scenario | Result |
|----------|--------|
| Cold start | CODE FIXED — `prepareSessionForDataFetch` single-flight |
| Warm start | CODE FIXED — same path |
| Foreground refresh | CODE FIXED — `scenePhase == .active` → `refreshOnForeground` |
| Offline recovery | PARTIAL — existing API timeouts; not newly device-proven |
| Partial readiness | CODE FIXED — dashboard paints when profile exists without waiting on location |

---

## 5. Geolocation (code status)

| Scenario | Result |
|----------|--------|
| Permission | CODE FIXED — grant posts `locationAuthorizationDidBecomeAuthorized` |
| Real location | CODE FIXED — auto bootstrap after Allow |
| Profile sync | UNCHANGED path `applyDeviceLocation` → PATCH |
| Dashboard refresh | Via `locationRevision` / notification |
| Planner refresh | Same notification path |
| Retry | Existing Retry UI retained |
| Restart | Uses cached coords then refreshes |

---

## 6. HealthKit (code status)

| Scenario | Result |
|----------|--------|
| Availability | Unchanged check |
| Authorization | Single-flight + 60s timeout |
| Partial permissions | Still opaque (Apple); sync background |
| Real records | Background sync after Connect returns |
| Backend sync | Bounded by 45s collect timeout |
| No records | `.dataUnavailable` retained |
| Timeout | CODE FIXED |
| Restart | Non-blocking dashboard sync retained |
| Revoke/reconnect | DEVICE PENDING |

---

## 7. Premium (code status)

| Scenario | Result |
|----------|--------|
| Catalog | Client unchanged; ASC empty catalog remains EXTERNAL if `Product.products` returns [] |
| Prices | DEVICE PENDING |
| Purchase | CODE FIXED finish-after-verify |
| Backend verify | Unchanged contract |
| Entitlement active | `sessionDidChange` now refreshes `/me` |
| Planner / Insights unlock | DEVICE PENDING |
| Restart / re-login / restore | CODE FIXED restore unfinished + honest empty message |
| Isolation | DEVICE PENDING |

---

## 8. Bugs Fixed (code)

1. Startup blocked / stale without foreground refresh  
2. Location never applied after Allow  
3. Health Connect/HealthKit Connect UI hang  
4. StoreKit verify leave unfinished txn / restore incomplete / entitlement skip on OAuth  

---

## 9. Commits

| Commit | Scope | Tests |
|--------|-------|-------|
| `85d9845` | startup refresh | AppSession prepare tests |
| `88021a0` | geolocation bootstrap | null-island test |
| `8823fcc` | HealthKit/HC hang | existing suite |
| `7df0d9c` | StoreKit premium | SubscriptionServiceTests |
| `38abf7f` | unit tests | AppSessionTests +14 selected |

---

## 10. Validation

| Check | Result |
|------|--------|
| Backend suite | PASS — 197 passed |
| iOS unit tests (AppSession + Subscription) | PASS — 14 tests |
| Android Health Connect connect | CODE FIXED (compile not re-run in this step) |
| Final gate | NOT RUN (defer to PR CI) |
| Physical device E2E | **NOT RUN** |

---

## 11. Production

| Item | Result |
|------|--------|
| Merge SHA | PENDING PR |
| Production SHA | Still `0243952` until merge+deploy |
| Deploy | Not yet |

---

## 12. TestFlight

| Item | Result |
|------|--------|
| Current known good engineering | Build **109** (pre-fix) |
| Post-merge required | Build **>109** from this branch |
| VALID / tester group | PENDING after archive |

---

## 13. Physical Device Evidence

| Integrated scenario | Result |
|---------------------|--------|
| Full fresh install → Premium → restart | **NOT RUN** |

---

## 14. Open P0/P1

| Severity | Count |
|----------|------:|
| P0 | 1 (physical retest incomplete) |
| P1 | ASC catalog empty risk if products still load as 0 |

---

## 15. Remaining External Blockers

- Physical iPhone retest on new TestFlight  
- ASC Paid Apps / IAP visibility if catalog empty  
- Play Console for Android device billing  
- Prefer Custom Cloudflare API Token (ops stability)

---

## 16. Final Verdict

**CODE FIXED — WAITING FOR PHYSICAL RETEST**
