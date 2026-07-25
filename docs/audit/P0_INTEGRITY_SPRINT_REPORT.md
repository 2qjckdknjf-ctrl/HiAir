# P0 Integrity Sprint Report

**Date:** 2026-07-25
**Branch:** `fix/p0-integrity-sprint` (from `origin/main` @ `3355fca`)
**Scope:** Phase 0 only — security, privacy, test stability. No growth features.
**Constraints honored:** no push, merge, production deploy, TestFlight, or store publish. PR #35 not used. User untracked files left untouched.

---

## Verdict (honest)

| Area | Status |
|------|--------|
| P0 Apple live JWS verification | **FIXED** (automated) |
| P0 Supabase auth bridge | **FIXED** (automated) |
| P0 Android health consent/revoke races | **FIXED** (automated) |
| P1 iOS unit-test suite timing/stability | **FIXED** (automated) |
| Phase 1 real-device certification | **NOT STARTED** — do not claim HealthKit / Health Connect / StoreKit / Play Billing physical success |

**Overall Phase 0 (post-review):** Review corrections applied. Code/tests on this branch close the Phase 0 integrity scope for automation. Production deploy of these fixes has **not** been performed. Physical/store readiness is **not** claimed.

---

## Post-review corrections (2026-07-25)

### A. Android remote cleanup — atomically honest

**Review finding:** `runCatching` in `revokeLocalFirst` / `retryRemoteCleanup` suppressed delete failures; partial cleanup could look successful; delete intent was not durable across restart.

**Fix:**
- New production orchestrator `WearableRemoteCleanup` + `WearableCleanupApi` (injectable).
- `deleteData=true` requires successful 2xx for health delete → wearable delete → consent revoke; exceptions are not swallowed.
- Durable prefs: `cleanup_delete_data`, per-step done flags; retry continues remaining steps; cannot downgrade pending delete → revoke-only.
- After full success: `pending=false`, `locallyRevoked=true`, uploads stay blocked until new consent; repeat call makes **no** API calls.
- UI still receives `remoteCleanupSucceeded=false` on any partial failure.

**Tests:** `HealthConsentRaceTest` rewritten to exercise **production** `WearableRemoteCleanup` with `FakeCleanupApi` (no real network). MutableGate-only / fake HTTP-status-only tests removed. **14** production-path cases (first/second delete 500, revoke 500 after deletes, timeouts, restart delete intent, idempotent retry, UI false, upload block, full 2xx, no re-call when complete).

### B. Apple live verifier — full fail-closed fields

**Review finding:** Missing fields could fall back to plan-based expiry / hashed transaction IDs; unknown `APPLE_STORE_ENVIRONMENT` silently became sandbox.

**Fix:** Live path requires `bundleId`, `environment`, `productId`, `transactionId`, `originalTransactionId`, `expiresDate`. No local 30/365-day substitute; no receipt-hash transaction IDs. Unknown environment → `RuntimeError`. Production still requires numeric `APPLE_APP_APPLE_ID`.

**Tests:** parametrized missing-field cases + unknown environment + no synthesize expires/tx + production App Apple ID requirement.

### D. Pending cleanup survives logout / account switch

**Review finding:** `clearConsentSession()` wiped pending delete tombstone on logout, so server data could remain while retry became impossible.

**Fix:**
- Separated **active consent session** from **account-bound cleanup tombstone** (`CleanupProgress.accountUserId` + durable prefs).
- `clearConsentSession()` / `cancelPendingOperations()` clear active consent and stop uploads, but **do not** delete pending cleanup intent/steps.
- Tombstone stores: account user ID, delete vs revoke, completed steps, pending flag, safe `lastErrorCategory` (no tokens, no health payload).
- Retry only when authenticated `userId` matches tombstone account; user B never triggers cleanup A and never sends token B to APIs for A.
- User B can consent independently without clearing A’s tombstone.
- Re-login of A continues remaining steps with the new token; full 2xx clears tombstone.
- Same-account consent is refused while a **delete** cleanup remains pending.

**Tests:** `HealthConsentRaceTest` exercises production `WearableRemoteCleanup` + `WearableConsentSessionCoordinator` with `FakeCleanupApi` (no real network): delete/revoke 500/timeouts, logout tombstone survival, same-user retry remaining steps, other-user isolation (no token B for A), account switch, consent block while delete pending, repeated logout, 401/timeout after re-login.

## 1. Reproduced defects → root cause → fix

### 1.1 Apple subscription verification (`alg=none` → Premium)

**Defect:** In `APPLE_STORE_VERIFIER_MODE=live`, `verify_ios_purchase()` decoded JWS payload without signature / Apple certificate-chain verification. Forged `alg=none` transactions could grant active Premium.

**Root cause:** Live path treated signed transaction as opaque JSON after base64 decode; stub and live were not fail-closed-separated.

**Fix:**
- Live path uses App Store Server Library `SignedDataVerifier` with bundled Apple root certs under `backend/app/resources/apple_root_certs/`.
- Validates signature, chain, bundle ID (`com.hiair.app`), environment, product ID, transaction IDs, expiration, revocation.
- Fail-closed on cert/config/decoder errors; never falls back to stub decode in live mode.
- Stub only when mode is explicitly `stub`.
- No logging of signed transaction / receipt payloads.
- Settings: `APPLE_STORE_ENVIRONMENT`, `APPLE_APP_APPLE_ID`; dependency `app-store-server-library` (+ `cryptography`).

### 1.2 Supabase auth bridge (admin create + auto-confirm)

**Defect:** Session endpoint could create users via admin API with `email_confirm=true`, turning unknown-email login into confirmed signup / account takeover risk.

**Root cause:** Bridge mixed password grant with privileged admin user provisioning.

**Fix:**
- `/auth/supabase/session` → password grant only (anon key).
- `/auth/supabase/signup` → explicit Supabase signup; respects email confirmation; returns 403 when confirmation required.
- No admin create/confirm on either path.
- iOS `AuthView` no longer treats bridge as auto-confirm fallback for unconfirmed email.
- Rate limiting retained; safe client-facing errors.

### 1.3 Android health consent / revoke races

**Defect:** Uploads could proceed after revoke/logout; non-2xx treated as success; work on wrong dispatcher; remote cleanup failure shown as full success.

**Root cause:** Missing durable local revoke gate, weak HTTP success checks, no pre-upload account/generation/consent re-check, in-flight sync not cancelled.

**Fix:**
- `HealthUploadGate` + durable local revoke; re-check consent / account / generation before every upload.
- Wearable APIs use strict 2xx (`requestStrict`); IO dispatcher; cancel in-flight sync on revoke/logout.
- Atomic remote cleanup via `WearableRemoteCleanup` / `WearableCleanupApi` (see Post-review corrections).
- UI distinguishes local stop vs pending remote cleanup (`remoteCleanupSucceeded=false` on partial failure).

### 1.4 iOS test suite hang / multi-minute races

**Defect:** Full `HiAirTests` hung or ran >20 minutes; individual timeout/race tests took 49–645s; MainActor / Core Location / real sleeps.

**Root cause:** Real `Task.sleep` / HealthKit timeouts in unit tests; actor+MainActor deadlocks in test gates; unstructured sync Task scheduling flakes; shared singleton pollution.

**Fix:**
- Injectable `Nanosleeping` / `ImmediateNanosleeper`; lock-based `TestAsyncGate` with cancel resume.
- Deterministic `runHealthSyncForTests`; upload gate counters; stub location in session tests; scheme parallelization off for HiAirTests.
- Race tests revoke/logout **inside** upload hook (no long probe waits).

---

## 2. Changed files (integrity sprint)

### Backend
- `backend/app/services/subscription_store.py`
- `backend/app/services/supabase_admin_auth.py`
- `backend/app/api/auth_supabase_bridge.py`
- `backend/app/core/settings.py`
- `backend/requirements.txt`
- `backend/scripts/check_env_security.py`
- `backend/app/resources/apple_root_certs/` (AppleIncRootCertificate.cer, AppleRootCA-G2.cer, AppleRootCA-G3.cer)
- `backend/tests/test_apple_live_verifier_security.py` **(new)**
- `backend/tests/test_supabase_auth_bridge_security.py` **(new)**
- `backend/tests/test_apple_deploy_config_propagation.py` **(new)**
- `backend/tests/test_supabase_auth_bridge.py`
- `.env.example`, `scripts/ops/deploy_hiair_api_cloudflare.sh`, `infra/cloudflare/hiair-api/src/index.js`
- `.github/workflows/backend-deploy-production.yml`, `.github/workflows/hiair-api-cloudflare.yml`
- `docs/subscriptions/SUBSCRIPTION_RELEASE_READINESS.md`

### Android
- `mobile/android/app/src/main/java/com/hiair/network/ApiClient.kt`
- `mobile/android/app/src/main/java/com/hiair/health/HealthConnectService.kt`
- `mobile/android/app/src/main/java/com/hiair/health/WearableHealthController.kt`
- `mobile/android/app/src/main/java/com/hiair/health/WearableHealthHost.kt`
- `mobile/android/app/src/main/java/com/hiair/health/HealthUploadGate.kt` **(new)**
- `mobile/android/app/src/main/java/com/hiair/health/WearableCleanupApi.kt` **(new)**
- `mobile/android/app/src/main/java/com/hiair/health/WearableRemoteCleanup.kt` **(new)**
- `mobile/android/app/src/main/java/com/hiair/SessionStore.kt`
- `mobile/android/app/src/main/java/com/hiair/AppMainActivity.kt`
- `mobile/android/app/src/main/java/com/hiair/ui/render/SettingsScreenRenderer.kt`
- `mobile/android/app/src/main/java/com/hiair/ui/settings/SettingsState.kt`
- `mobile/android/app/src/main/java/com/hiair/ui/i18n/AndroidL10n.kt`
- `mobile/android/app/src/test/java/com/hiair/StoredSessionTest.kt`
- `mobile/android/app/src/test/java/com/hiair/health/HealthConsentRaceTest.kt` (rewritten: production cleanup flow + fake API)

### iOS
- `mobile/ios/HiAir/Services/HealthKitService.swift`
- `mobile/ios/HiAir/Services/HealthKitTimeoutRace.swift`
- `mobile/ios/HiAir/Services/LocationService.swift`
- `mobile/ios/HiAir/AppSession.swift`
- `mobile/ios/HiAir/Screens/AuthView.swift`
- `mobile/ios/HiAirTests/RuntimeUXRecoveryTests.swift`
- `mobile/ios/HiAirTests/HealthKitTimeoutRaceTests.swift`
- `mobile/ios/HiAirTests/HealthKitAuthorizationSingleFlightTests.swift`
- `mobile/ios/HiAirTests/AppSessionTests.swift`
- `mobile/ios/HiAir.xcodeproj/xcshareddata/xcschemes/HiAir.xcscheme`

### Docs
- `docs/audit/P0_INTEGRITY_SPRINT_REPORT.md` (this file)

---

## 3. Added / focused tests

### Apple live verifier
- unsigned `alg=none` rejected
- corrupted signature rejected
- post-signature payload tamper rejected
- wrong bundle ID / environment / unknown product rejected
- expired / revoked → not active Premium
- verified fixture → correct entitlement
- verifier unavailable → no Premium
- live never falls back to stub decode

### Auth bridge
- session never calls admin create
- unknown email login does not create user
- signup ≠ signin
- existing email cannot be hijacked
- unconfirmed email not auto-confirmed
- service role not required; bridge disable → 404

### Android consent / cleanup (production path)
- `WearableRemoteCleanup` + `FakeCleanupApi`: delete1/delete2/revoke 500, timeouts, partial pending, restart `deleteData=true`, idempotent retry, UI `remoteCleanupSucceeded=false`, uploads blocked after any partial failure, full 2xx clears pending, already-complete skips network
- No real network; MutableGate-only stubs removed

### iOS race / timeout
- revoke / delete / logout / account-switch at upload gate with `testUploadGateReachedCount > 0` and `testUploadAttemptCount == 0`
- cancel after collect; generation replace; remote revoke failure blocks sync
- timeout races use immediate sleeper (sub-second)

---

## 4. Verification results (this machine)

| Suite | Result | Notes |
|-------|--------|-------|
| Backend pytest (full) | **235 passed** | coverage **72.98%** (≥70% gate) |
| Backend Apple + auth + deploy config subset | **37 passed** | live verifier + auth bridge + deploy propagation |
| Android `test` + `assembleDebug`/`Release` + `lintDebug` | **SUCCESS** | **15** HealthConsentRaceTest (incl. logout tombstone); debug+release unit |
| iOS `HiAirTests` post-tombstone run 1 | **70/70, 0 failures** | wall **~10.0s** |
| iOS `HiAirTests` post-tombstone run 2 | **70/70, 0 failures** | wall **~10.9s** |
| Static deploy allowlist checks | **PASS** | via `test_apple_deploy_config_propagation.py` |

### iOS suite timing (before → after)

| Metric | Before (audit) | After |
|--------|----------------|-------|
| Full suite | hung / **>20 min** | **~9–13 s** wall (target **&lt;5 min**) |
| Race class | ~645 s | **&lt;0.2 s** class body |
| Timeout / single-flight | 49–151 s / ~109 s | **sub-second** with injectable sleeper |
| Repeatability | unstable | consecutive green runs (incl. post-review) |

---

## 5. Proven by automation vs physical-only

**Proven automatically:**
- Forged / unsigned / tampered Apple JWS cannot grant Premium in live mode; missing required live fields / unknown env fail closed.
- Auth bridge cannot admin-create or auto-confirm; signup/login separated.
- Android **production** remote cleanup path: partial delete/revoke failures keep pending + block uploads; restart preserves `deleteData`; complete cleanup does not re-hit the server.
- Deploy allowlists carry `APPLE_STORE_ENVIRONMENT` / `APPLE_APP_APPLE_ID`; production checks reject stub Apple verifier.
- iOS unit suite completes stably under 5 minutes without real HealthKit/network sleeps.

**Not proven (Phase 1 / device):**
- Real App Store Server API + StoreKit sandbox purchase → live verify on `api.hiair.io`.
- Real Supabase email confirmation email delivery and mobile UX on device.
- Real HealthKit / Health Connect permission sheets, background delivery, revoke in system Settings.
- Production deploy / secret sync of this branch (**not performed**).

---

## 6. Residual P1 / P2 risks

1. **Operator secrets:** Production GH/Cloudflare secrets must actually supply live Apple env + numeric App Apple ID before next deploy (checks will fail closed otherwise).
2. **Google Play verifier:** Still separate from this P0 Apple focus.
3. **iOS production sync** still uses unstructured `Task` in `startBackgroundHealthSync` — device race certification still required.
4. **Auth UX** copy QA on device for confirmation vs invalid credentials.
5. **Coverage:** Backend ~73%; real SignedDataVerifier crypto still needs sandbox fixtures in Phase 1.
6. **Uncommitted branch:** `fix/p0-integrity-sprint` working tree; **not pushed**. Commit/PR only when owner requests.

---

## 7. Phase 1 recommendation

Phase 0 review items are **closed in code/tests**. Proceed to Phase 1 Real-device certification **after** commit/review and production Apple secret provisioning. Do **not** claim STORE SANDBOX READY or physical Health Connect/HealthKit/StoreKit success from this sprint.
