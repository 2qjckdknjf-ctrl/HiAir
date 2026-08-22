# Store-Ready Execution Report — 2026-08-22

**Worktree:** `/Users/alex/Projects/HIAir-store-ready`  
**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**Release-candidate SHA (in progress):** see `git rev-parse HEAD` after final commits  
**Base integrated:** `origin/main` (`fe132d94`) → production lineage `537090b3` → store hardening commits  
**Status ladder:** `CODE-READY / EXTERNAL ACTIONS REQUIRED` (not `STORE-READY`)

---

## Executive verdict

| Verdict | Reason |
|---------|--------|
| **CODE-READY / EXTERNAL ACTIONS REQUIRED** | P0 backend issues fixed and verified locally (pytest, clean `init_db`, `smoke_db_flow`). iOS PurchaseAction + paywall `fullScreenCover` integrated; build **213**. Android build **189** with nav/auth fixes. Signed store artifacts, physical-device IAP, ASC/Play console tasks, and production deploy remain owner/external. |

---

## Git provenance

| Item | Value |
|------|-------|
| Source worktree (untouched) | `/Users/alex/Projects/HIAir` @ `design/redesign-v4-deep-glass` / `da85e430` |
| RC worktree | `/Users/alex/Projects/HIAir-store-ready` |
| `origin/main` at start | `fe132d9401dbd14c602b1537ff3243bc3bf653cf` (unchanged after fetch) |
| Production backend SHA (pre-fix) | `537090b335f40cdad4a1526e469067a24b112add` |
| iOS build target | **213** (`MARKETING_VERSION` 1.0) |
| Android versionCode | **189** (`versionName` 1.0.0) |

### Known lineage gaps (honest)

- ASC submission build **187** (`WAITING_FOR_REVIEW`) — source SHA not recorded in repo.
- Last valid internal ASC build **212** @ `f80219bc` — missing PurchaseAction, saved-place 402 UX, alert cooldown by type, NO2 UI.
- Android internal **188** @ `6ddcff2a` — not proven identical to evidence AAB checksums.
- Production API currently reports deploy SHA `537090b3` (manual deploy despite red CI — policy violation; workflow fixed locally, **not deployed**).

---

## Issue register

### P0

| ID | Problem | Root cause | Fix | Verification | Status |
|----|---------|------------|-----|--------------|--------|
| P0-001 | Clean PostgreSQL init fails on migration 021 | `auth.uid()` RLS in same file as table DDL; CI DB has no `auth` schema | Split DDL (021–023) from RLS (`025_supabase_table_rls.sql`, auth-gated in `init_db.py`) | `init_db.py` on fresh DB: 18 migrations applied, 025 skipped | **FIXED** |
| P0-002 | Account deletion incomplete | `privacy_repository.delete_user_data` only; no Supabase Auth delete; fail-open success | New `account_deletion.py` orchestrator with stage model, retries, audit table `026`, honest API responses | 19 new/updated tests + `smoke_db_flow` delete path | **FIXED** |
| P0-003 | Production deploy bypasses red CI | `workflow_dispatch` without pytest/clean DB gate | `release-preflight` job: full gate + `init_db` + `smoke_db_flow`; deploy `needs` preflight; ref policy | Workflow YAML review (not executed deploy) | **FIXED** |
| P0-004 | iPad StoreKit / App Review 2.1(b) | Scene-based purchase without window on iPadOS 26 | Cherry-pick `da85e430`: `PurchaseAction`, `appAccountToken`, plan card disclosures | Commit integrated; UITest added (simulator not re-run this session) | **FIXED** (sim re-verify pending) |
| P0-005 | Paywall presentation | `.sheet` on iPad | `RootTabView` → `.fullScreenCover` | Code change | **FIXED** |

### P1 (addressed locally)

| ID | Problem | Fix | Status |
|----|---------|-----|--------|
| P1-001 | Android nav blur on icons/text | Removed `RenderEffect` on `navRow`; glass drawable only | **FIXED** |
| P1-002 | Android bottom nav before auth | Hide `navRow`/`titleView` until authenticated + onboarding complete | **FIXED** |
| P1-003 | `app-store-server-library` unpinned | Pinned in `requirements.txt` | **FIXED** |
| P1-004 | Build numbers below store lineage | iOS 213, Android 189 | **FIXED** |

### P1/P2 remaining

| ID | Problem | Status |
|----|---------|--------|
| P1-005 | Deep Glass V4 full visual parity (design branch unmerged) | **NOT FIXED** — selective ports only |
| P1-006 | Dynamic Type (`HiAirTypography.scaled` stub) | **NOT FIXED** |
| P1-007 | iOS accessibility contrast / Settings segmented controls | **NOT FIXED** |
| P1-008 | Fresh screenshot matrix (iOS/Android all devices/states) | **NOT VERIFIED** |
| P2-001 | Documentation truth alignment (`05_RELEASE_READINESS`, handoff build numbers) | **PARTIAL** (this report only) |
| P2-002 | Google Play API 36 target | **NOT VERIFIED** (still targetSdk 35) |

---

## Gate results (this session)

### Backend

| Gate | Result |
|------|--------|
| `pytest tests` (full) | **PASS** — 75.34% coverage (≥70%) |
| `init_db.py` clean PostgreSQL | **PASS** |
| `smoke_db_flow.py` | **PASS** |
| `pip-audit` | Not re-run this session |

### Android

| Gate | Result |
|------|--------|
| `testDebugUnitTest` | **PASS** |
| `lintDebug` | **PASS** |

### iOS

| Gate | Result |
|------|--------|
| Clean build / archive | **NOT RUN** (no signing credentials in RC worktree) |
| StoreScreenshotTests | **NOT RUN** this session |
| iPad Sandbox Purchase UITests | **NOT RUN** this session |

---

## Production secrets required (account deletion) — do not commit

| Secret / setting | Purpose |
|------------------|---------|
| `SUPABASE_URL` | Admin API base |
| `SUPABASE_SERVICE_ROLE_KEY` | `DELETE /auth/v1/admin/users/{id}` |
| `APPLE_TEAM_ID` | Sign in with Apple client secret |
| `APPLE_SIGN_IN_KEY_ID` | ES256 `kid` |
| `APPLE_SERVICES_ID` | `com.hiair.app.auth` |
| `APPLE_SIGN_IN_P8_PATH` | Container path to `.p8` (mount in Cloudflare secrets file writer) |

Deploy workflow updated to propagate `APPLE_TEAM_ID`, `APPLE_SIGN_IN_KEY_ID`, `APPLE_SERVICES_ID`, `APPLE_SIGN_IN_P8_PATH` to Cloudflare env file.

---

## Owner action checklist

### GitHub
- [ ] Change default branch from `cursor/bootstrap-ci-and-tooling` → `main` (repo Settings → Branches).
- [ ] Merge `cursor/store-ready-hardening-2026-08-22` via PR after review (do not merge blind `design/redesign-v4-deep-glass`).
- [ ] Close/rebase draft PRs targeting wrong default branch.

### Cloudflare / backend
- [ ] Deploy only after green `release-preflight` on release SHA.
- [ ] Add Apple Sign-In P8 path/key to production secrets.
- [ ] Verify `/api/health` `deploy_sha` matches merged commit.

### App Store Connect
- [ ] Upload iOS build **>212** from RC SHA after Xcode Cloud archive.
- [ ] Update Review Notes (`docs/release/store/APP_REVIEW_INFORMATION_NEEDED.md`) with 2.1(b) PurchaseAction fix.
- [ ] Do **not** replace build 187 submission without explicit owner approval.

### Google Play Console
- [ ] Upload AAB versionCode **>189** from same SHA.
- [ ] Complete IARC, Data Safety, Health apps declaration.
- [ ] Confirm uploaded binary SHA-256 against local manifest.

### Physical devices
- [ ] Sandbox Apple Account IAP purchase + Restore (iPhone + iPad).
- [ ] Play License tester IAP on phone + tablet.
- [ ] Account deletion E2E with Apple authorization code on iOS.

---

## External blockers (cannot complete locally)

1. App Store / Play **signing & upload** credentials  
2. **Physical device** IAP and account-deletion verification  
3. **Production deploy** (explicitly forbidden this session)  
4. **Deep Glass V4** full design merge from dirty `design/redesign-v4-deep-glass` worktree  
5. **Screenshot/visual QA matrix** across all device classes  

---

## Recovery: partial account deletion

If `POST /api/privacy/delete-account` returns **503** with `stages` showing a failed step:

1. User may retry with same bearer token if auth user still exists.
2. Operator checks `account_deletion_audit` (hashed `user_id`, stage JSON, no PII).
3. For stuck `supabase_auth`, manually delete `auth.users` via Supabase admin after confirming public data removed.
4. For failed `apple_revoke`, user must re-authenticate with Apple and retry with fresh `apple_authorization_code`.

---

*Last updated: 2026-08-22 — autonomous RC hardening session*
