# P0 Integrity Sprint Report

**Date:** 2026-07-26
**Branch:** `fix/p0-integrity-sprint` (from `origin/main` @ `3355fca`)
**Scope:** Phase 0 only — security, privacy, test stability. No growth features.
**Constraints honored:** no push, merge, production deploy, TestFlight, or store publish. PR #35 not used. User untracked files left untouched.

---

## Verdict (honest)

| Area | Status |
|------|--------|
| P0 Apple live JWS verification | **FIXED** (automated) |
| P0 Supabase auth bridge | **FIXED** (automated) — includes tokens+unconfirmed → confirmation-required |
| P0 Android health consent/revoke races | **FIXED** (automated) — includes cold-start tombstone retry bind |
| P1 iOS unit-test suite timing/stability | **FIXED** (automated) |
| Phase 0.5 Google Play live verifier fail-closed | **FIXED** (automated) — see §7 |
| Phase 0.6 iOS health sync coordinator race | **FIXED** (automated) — see §7b |
| Phase 0.7 production environmental truth | **FIXED** (automated) — sample/mock forbidden in prod; smoke honesty |
| Phase 1 real-device certification | **BLOCKED** — preflight complete; physical iPhone offline and no physical Android device connected |

**Overall Phase 0 (post-review + Bugbot + production truth):** Code/tests on this branch close the Phase 0 integrity scope for automation, including PR #36 Bugbot High/Medium blockers. Production deploy of these fixes has **not** been performed. Physical/store readiness is **not** claimed.

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
| Backend pytest (full) | **297 passed** | coverage **74.63%** (≥70% gate) |
| Backend Apple + auth + deploy + Google + smoke subset | **PASS** | live verifiers + auth bridge + sample forbid + post-deploy honesty |
| Android `test` + `assembleDebug`/`Release` + `lintDebug` | **SUCCESS** | **16** HealthConsentRaceTest (incl. cold-start bind); debug+release unit **108**/0 fail |
| iOS `HiAirTests` fresh DerivedData (`CODE_SIGNING_ALLOWED=NO`, iPhone 17) | **89/89, 0 failures** | wall **~1.8s** test body; includes logout transport suite |
| `hiair_final_gate.sh` (non-strict) | **PASS** | automation green |
| `check_external_readiness.py --strict` | **BLOCKED** | `MISSING=0`, `BLOCKED=1` (0 PASS / 40 unresolved physical rows) |
| Sign-off checker | **BLOCKED** | 0/4 owner DONE markers |
| Static deploy allowlist checks | **PASS** | Apple + Google SA + `ENVIRONMENT_ALLOW_SAMPLE_FALLBACK=false` |

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

1. **Operator secrets:** Production GH/Cloudflare secrets must supply live Apple env + numeric App Apple ID **and** `GOOGLE_PLAY_VERIFIER_MODE=live` + `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` before next deploy (checks fail closed otherwise).
2. **Google Play live verifier (automated):** Fail-closed parsing + production stub rejection landed in Phase 0.5 (see below). Real Play Billing sandbox purchase → live verify on `api.hiair.io` still requires Phase 1 / operator Play Console access.
3. **iOS health sync coordinator (automated):** Phase 0.6 closed the nested unstructured clear-Task race; production path is MainActor-bound + generation-gated `finishSyncInFlight`. Physical revoke-during-sync still needed in Phase 1.
4. **Auth UX** copy QA on device for confirmation vs invalid credentials.
5. **Coverage:** Backend ~74%; real SignedDataVerifier crypto still needs sandbox fixtures in Phase 1.
6. **Uncommitted Phase 0.5/0.6 delta:** Closed into PR #36 commits (2026-07-26). Remaining residual is physical/store only.

---

## 7d. Bugbot review blockers + production truth (2026-07-26)

**PR #36 Bugbot High — signup tokens without confirmation:**
- Defect: guard only fired when tokens were empty, so Supabase responses with access/refresh + unconfirmed user issued a session.
- Fix: require non-empty `email_confirmed_at`/`confirmed_at`; otherwise `SupabaseEmailConfirmationRequired` (403, no session, no enumeration).
- Test: `test_signup_tokens_without_email_confirmation_require_confirmation`.

**PR #36 Bugbot Medium — Android cold start:**
- Defect: `restoreSession()` did not call `onAuthenticatedUserChanged`, so durable tombstones were not retried until a later `persistSession()`.
- Fix: bind restored user/generation/token immediately after restore (and after OAuth consume).
- Test: `coldStart_restoreSessionBinding_retriesPendingWithRestoredTokenNotOtherAccount`.

**Production environmental truth:**
- Protected `APP_ENV` defaults `ENVIRONMENT_ALLOW_SAMPLE_FALLBACK=false`.
- Public `/api/environment/snapshot` rejects `source=sample|mock` in production/staging; unavailable live/cache → 503 (no synthetic data).
- Deploy forces `ENVIRONMENT_ALLOW_SAMPLE_FALLBACK=false` and syncs `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` into Cloudflare allowlists/container env.
- `post_deploy_api_smoke.py`: rejects served sample; `--require-live-ai` without admin token → FAIL (SKIP only without the flag).

**Not claimed:** production deploy, STORE SANDBOX READY, physical QA PASS.

## 7. Phase 0.5 — Google Play live verifier fail-closed (2026-07-25)

**Why:** Phase 1 real-device certification is blocked without physical devices / TestFlight / deploy. Highest-priority remaining *code-bounded* integrity item from Phase 0 residual risk #2 was Google Play live verification parity with Apple.

**Defects closed (automated):**
- Live path could accept the first `lineItems` entry when product ID mismatched.
- Missing `expiryTime` synthesized 30/365-day plan expiry.
- Missing `latestOrderId` synthesized a purchase-token hash as transaction ID.
- Unknown / unspecified `subscriptionState` mapped to `"unknown"` instead of reject.
- Incomplete service-account JSON accepted; production allowlists still permitted `GOOGLE_PLAY_VERIFIER_MODE=stub`.

**Fix:**
- `verified_purchase_from_google_subscription()` — exact product match, required `expiryTime` / `latestOrderId` / `subscriptionState`, optional packageName match, empty token reject.
- Network/oauth failures → `RuntimeError("Google Play verifier unavailable")` (no stub fallback); missing SA config stays explicit.
- `check_env_security` + Cloudflare deploy script reject Google stub / missing SA in production/staging (parity with Apple).

**Tests:** `backend/tests/test_google_play_live_verifier_security.py` + deploy/env gate updates in `test_apple_deploy_config_propagation.py`.

**Corrective audit (same day — local closure):**
- Ambiguous duplicate `lineItems` with the **same** exact `productId` → **reject** (no first-wins).
- `autoRenew` mapping fail-closed: `prepaidPlan` ⇒ `False`; `autoRenewingPlan` requires an explicit boolean `autoRenewEnabled` (missing / non-boolean / both plan types / neither plan → reject; no default `True`).
- Focused Google suite + full backend pytest via `.tools/py/python` → PASS; coverage **74.51%** (≥70%).

**Not claimed:** STORE SANDBOX READY, physical Play Billing success, or production deploy of this branch.

---

## 7b. Phase 0.6 — iOS health sync coordinator race (2026-07-25)

**Why:** Residual risk #3 after Phase 0/0.5 — production `startBackgroundHealthSync` used an unstructured Task whose `defer` cleared `syncInFlight` via a **nested** unstructured `Task { @MainActor }`, which could race a replacement sync and wipe the newer handle.

**Fix:**
- Production coordinator is explicitly `Task { @MainActor ... }` (same pattern as authorization single-flight).
- `finishSyncInFlight(generation:)` clears synchronously on MainActor only when the generation is still current — no nested clear Task.
- `beginHealthSyncGeneration` cancels prior work and **immediately nils** `syncInFlight` so a cancelled/completed stale handle cannot look in-flight before replacement assignment.
- `runHealthSyncForTests` schedules the same MainActor coordinator Task (via detached hop so XCTest caller cancellation is not inherited) and awaits completion through a checked continuation.
- `AppSession` stores/cancels startup + prepare + signOut + place-invalidate Tasks and removes **all** NotificationCenter observers on `deinit` / `cancelLifecycleForTests`.
- `SupabaseAuthService.signOut` does **not** re-broadcast `sessionDidChange(nil)` when already signed out (avoids host AppSession logout storms during unit tests without changing logout→`clearAccountSession` semantics).
- **Logout remote revoke (security regression fix):** `AppSession.logout()` captures an **account-correlated** immutable snapshot before local clear: global `APIClient` bearer is used only when `global.userId == session.userId`; otherwise the session’s own local token is revoked. Stale session A never revokes/clears account B (`APIClient` / Health binding owned by B). Local clear is immediate for the logging-out session. Remote path is `AuthRemoteSessionRevoking.revokeRemoteSession(accessToken:)` → production `SupabaseAuthService` POST `/auth/v1/logout` with captured Bearer (no `sessionDidChange(nil)` recursion). Concurrent same-bearer logout is deduped.
- **Durable store ownership:** `SessionDurableOwnership` generation gate — only the current owner may mutate shared credential store + account-scoped `UserDefaults`. Owning logout clears durable credentials under the claimed generation then bumps ownership. `installAuthSession` deliberately claims a new generation so account B becomes sole writer and stale A loses mutation rights.
- **Credential store seam (corrective pass 4):** `SessionCredentialStoring` protocol — production default `KeychainStore` (unchanged SecItem path); unit tests inject `InMemorySessionCredentialStore` so ownership/relaunch proofs are deterministic under `CODE_SIGNING_ALLOWED=NO` (real Keychain SecItem writes can silently fail without a signed identity). Production path is not weakened.

**False CLOSED (corrective pass 3 — rejected):** Prior claim that durable ownership was CLOSED was **invalid**. Independent reproduction with brand-new DerivedData + `CODE_SIGNING_ALLOWED=NO` failed: `AppSessionLogoutRemoteRevokeTests` **8** tests / **24** assertion failures; `peekAuth()` nil immediately after `installAuthSession` because harness used real `KeychainStore` whose writes are non-deterministic when unsigned. Transport suite still **6/6**. XCResult cited by reviewer: `/tmp/hiair-codex-logout-verify3/Logs/Test/Test-HiAir-2026.07.25_19-16-01-+0200.xcresult`.

**Test isolation (corrective audit — production fence rejected):**
- Removed any `unitTestIsolationActive` / AppSession bypass that skipped `HealthKitService.shared.clearAccountSession()`.
- Logout / account switch **always** clears shared HealthKit presentation (production invariant).
- `HealthSyncCoordinatorRaceTests` construct an isolated `HealthKitService(defaults: ephemeral suite)`.
- Logout durable proofs use ephemeral `UserDefaults` suite + **in-memory** `SessionCredentialStoring` + `SessionDurableOwnership` (no residual simulator Keychain / signed-build dependence).
- Proven by:
  - `SupabaseAuthLogoutTransportTests` — exact outbound Bearer contract (unchanged).
  - `AppSessionLogoutRemoteRevokeTests` (**9**): stale A vs durable B + relaunch; owning logout → fresh unauthenticated; `testInstallAuthSessionTransfersDurableOwnershipAndStaleALosesMutationRights`.

**Validation (corrective pass 4 — 2026-07-25 — independent reproduction):**
- Exact command (brand-new DerivedData, `CODE_SIGNING_ALLOWED=NO`, destination `1B982CA7-4365-4034-9998-60C5D9B51ADE`) ×2:
  - `/tmp/hiair-codex-logout-verify5` → **15/15** PASS (logout **9** + transport **6**), exit 0
  - `/tmp/hiair-codex-logout-verify6` → **15/15** PASS, exit 0
- Full `HiAirTests` ×2 with `CODE_SIGNING_ALLOWED=NO` + fresh DerivedData:
  - `/tmp/hiair-codex-full-verify1` → **89/89** PASS
  - `/tmp/hiair-codex-full-verify2` → **89/89** PASS
- `git diff --check` on touched files → clean.
- No commit/push/deploy.

**Not claimed:** Device race certification or STORE SANDBOX READY.

---

## 7c. Phase 1 preflight + release-gate honesty (2026-07-26)

**Preflight result:** Local automation remains green, but physical certification cannot start in
this session: Xcode sees the physical iPhone as **offline** and Android exposes only an emulator.
No HealthKit / Health Connect / StoreKit / Play Billing physical PASS is claimed.

**Release-gate finding:** `check_qa_execution()` counted historical `| PASS |` rows from backend /
production preflight tables anywhere in `REAL_DEVICE_QA_REPORT.md`. That falsely reported
`REAL_DEVICE_QA_EXECUTION=DONE` while the current physical matrices were `NOT RUN`.

**Fix:**
- The checker now reads only an explicit `## Current release certification` section.
- `Status: PASS` is accepted only when that section has at least one PASS row and zero
  `BLOCKED` / `NOT RUN` / `FAIL` rows.
- The current iOS + Android matrix is explicit and stays `Status: BLOCKED` until physical evidence
  exists; historical PASS rows cannot close it.
- Owner-action output now points to physical-device execution instead of incorrectly asking for
  env updates when no env keys are missing.

**Validation:**
- `scripts/release/hiair_final_gate.sh` (non-strict) → **PASS**: backend, Debug/Release iOS
  simulator builds, Android unit/debug/release/lint, config and secret-baseline checks.
- Full backend after gate hardening → **287/287 PASS**, coverage **74.51%**.
- Release checker regression tests → **4/4 PASS**.
- `check_external_readiness.py --strict` → expected **exit 1**:
  `MISSING=0`, `BLOCKED=1`, current device matrix **0 PASS / 40 unresolved**.
- Fresh unsigned iOS DerivedData after Swift concurrency-warning cleanup →
  **89/89 PASS**, no compiler warnings, at
  `/tmp/hiair-codex-phase1-gate-20260726-3.xcresult`.
- `git diff --check` → clean.
- No commit/push/deploy.

---

## 8. Phase 1 recommendation

Phase 0 review items remain **closed**. Phase 0.5 Google Play automated fail-closed and Phase 0.6 iOS sync coordinator hardening (including logout transport Bearer + durable stale-account ownership with deterministic credential-store seam) are **closed locally in code/tests** only after the pass-4 independent `CODE_SIGNING_ALLOWED=NO` reproduction above. Proceed to Phase 1 Real-device certification **after** commit/review and production Apple **+** Google secret provisioning. Do **not** claim STORE SANDBOX READY or physical Health Connect/HealthKit/StoreKit/Play Billing success from this sprint.
