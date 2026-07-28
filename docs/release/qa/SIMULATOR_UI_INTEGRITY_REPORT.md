# Simulator UI Integrity Sprint Report

**Verdict:** `SIMULATOR UI INTEGRITY PASS — READY FOR REVIEW`

**Date:** 2026-07-28  
**Branch:** `fix/ios-ui-integrity-simulator`  
**Baseline SHA:** `6c3f52258c89334753ebc287a2b7d7de612a06d1` (`origin/main`)  
**Simulator:** iPhone 17 / iOS 26.5  

## Defects found and fixed

| Severity | Defect | Root cause | Fix |
|---|---|---|---|
| P0 | Dashboard CTA «Создать профиль автоматически» silently no-ops | `ensureProfileIdIfNeeded()` returned `Bool`/`false` with empty `catch` and no UI message (missing location or API error) | Typed `ProfileEnsureOutcome`, published loading/error state, shared `ProfileBootstrapCard`, RU/EN messages, analytics without tokens |
| P1 | Concurrent/auto bootstrap could hide CTA during UI tests / race create | `refreshOnForeground` / location-auth observer / prepareSession auto-called ensure | Single-flight ensure + UITest `UITEST_DISABLE_AUTO_PROFILE` guards |
| P2 | Missing stable accessibility identifiers for critical CTAs | No a11y ID convention | `HiAirAccessibilityID` + identifiers on auth/onboarding/tabs/profile/settings/paywall |

## Gates

| Gate | Result |
|---|---|
| Unit tests (`HiAirTests`) | **101 passed**, 0 failed |
| New profile-ensure unit tests | **12 passed** (auth/location/create/list/401/403/503/offline/single-flight/idempotent/RU-EN) |
| UI tests ×3 consecutive | **9/9 × 3 = PASS** (logs under `.evidence/simulator-ui-integrity/logs/uitest-x3-run{1,2,3}.txt`) |
| `git diff --check` | clean |
| Production secrets / env flips | unchanged |
| Physical TF145 evidence | untouched |

## UI coverage (postcondition-checked)

- Auth controls present (unsigned)
- Profile create success (mock API) — CTA disappears
- Profile needs location — visible error + retry affordance
- Profile 503 — visible error, CTA remains
- Profile 401 — session expired → auth root
- Double-tap settle (no stuck loading)
- Tabs dashboard→planner→insights→symptoms→settings
- Paywall open/close
- Logout → auth
- EN create-profile label

Code-derived inventory: `.evidence/simulator-ui-integrity/matrix/SCREEN_ACTION_INVENTORY.md` (81 interactive bindings). Not every binding has a dedicated XCUITest; critical dead-CTA class and navigation smoke are automated.

## StoreKit

- Config present: `mobile/ios/HiAir/Configuration/HiAirPremium.storekit`
- UI: paywall present + close verified
- Purchase/restore cryptographic paths covered by existing `SubscriptionServiceTests` (unit); full StoreKit Test purchase gesture not claimed as PASS in this sprint

## Non-claims

- Simulator PASS ≠ physical iPhone PASS
- Simulator PASS ≠ TestFlight 145 fixed (needs new TF build >145)
- HealthKit / real permissions / StoreKit sandbox / physical QA must be re-run on new build
- Android billing remains disabled unless separately changed
- Production deploy was not performed
- App Store / External TestFlight were not modified

## Evidence paths

- `.evidence/simulator-ui-integrity/logs/`
- `.evidence/simulator-ui-integrity/matrix/SCREEN_ACTION_INVENTORY.md`
- XCTest screenshot attachments in xcresult bundles under DerivedData `Logs/Test/`
