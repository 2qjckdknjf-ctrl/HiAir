# Store-Ready Execution Report — 2026-08-22

**Worktree:** `/Users/alex/Projects/HIAir-store-ready`  
**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**Current HEAD:** see `git rev-parse HEAD` (not final RC until hardening closes)  
**Status ladder:** **`NO-GO / HARDENING IN PROGRESS`**

---

## Executive verdict

| Verdict | Reason |
|---------|--------|
| **NO-GO / HARDENING IN PROGRESS** | P0 backend account deletion, migrations, and deploy policy are now fail-closed with tests. iOS/Android simulator gates pass locally. Deep Glass V4 selective integration, full accessibility matrix, iPad screenshot matrix, signed store artifacts, physical IAP, and production deploy remain open. |

---

## P0 closure (this session)

| ID | Area | Status | Evidence |
|----|------|--------|----------|
| P0 Account Deletion | Durable operations, server-side Apple revoke, P8 content secret, per-stage commits, crash/retry tests | **CLOSED locally** | `pytest tests/test_account_deletion.py` + full suite |
| P0 Migrations | Portable DDL for 014/018; Supabase layer in 028; schema contract test | **CLOSED locally** | `test_schema_contract.py` + `init_db` on clean PostgreSQL |
| P0 Deploy policy | Immutable `resolved_release_sha`, main-only dispatch, shared checkout | **CLOSED locally** | `test_production_deploy_policy.py` + workflow YAML (not deployed) |

---

## Local gates (verified)

| Gate | Result |
|------|--------|
| Backend `pytest` (full) | **PASS** — ~74–75% coverage |
| `init_db` + schema contract | **PASS** |
| iOS simulator `build` | **PASS** |
| iOS `HiAirTests` (189 tests) | **PASS** |
| iOS `HiAirUITests` (15 tests) | **PASS** |
| Android `testDebugUnitTest` + `lintDebug` | **PASS** |
| Android `assembleRelease` + `bundleRelease` (API 36) | **PASS** |

---

## Still open (blocks CODE-READY)

| Area | Status |
|------|--------|
| Deep Glass V4 selective integration | **NOT DONE** |
| iOS accessibility/contrast audit (Settings, DatePicker, Insights, iPad) | **PARTIAL** (Dynamic Type scaling added; screen-by-screen audit incomplete) |
| Full screenshot matrix (iPhone Pro, iPad 13", Android phone/tablet, a11y text) | **IN PROGRESS** |
| PurchaseAction / iPad StoreKit | **IMPLEMENTED — NOT VERIFIED** on physical iPad / Sandbox purchase |
| Signed iOS archive / Play upload | **EXTERNAL** (no signing credentials in worktree) |
| Production deploy | **EXTERNAL** (explicitly forbidden this sprint) |
| Docs truth-alignment (`05_RELEASE_READINESS`, handoffs, `08_KNOWN_GAPS`) | **PARTIAL** (this report + manifest) |

---

## Build numbers (honest)

| Platform | RC value | Store evidence |
|----------|----------|----------------|
| iOS `CFBundleVersion` | **213** | Not uploaded from this worktree; ASC internal lineage through **212** @ `f80219bc` |
| Android `versionCode` | **189** | Play internal max evidence **188** — **189 is next free** |

---

## Artifacts

Manifest: [`docs/release/artifacts/rc-2026-08-22/MANIFEST.md`](../release/artifacts/rc-2026-08-22/MANIFEST.md)

- Android release AAB (unsigned if no keystore): `mobile/android/app/build/outputs/bundle/release/app-release.aab`
- iOS simulator `.app`: Xcode DerivedData Debug-iphonesimulator build
- **Not produced:** signed `.ipa`, ASC/Play upload packages

---

## Commits (store-ready branch)

Atomic commits after user rejection of premature CODE-READY:

1. `fix(backend): fail-closed durable account deletion operations`
2. `fix(backend): split portable migrations from Supabase auth layer`
3. `fix(ci): enforce immutable production deploy SHA policy`
4. `fix(mobile): onboarding auth CTA, Dynamic Type, and paywall build fixes`

---

## External-only (unchanged)

- ASC / Play console uploads and metadata submission
- Physical-device IAP (Sandbox Apple Account)
- Production deploy to `api.hiair.io`
- Apple/Google signing credentials for store-ready binaries
