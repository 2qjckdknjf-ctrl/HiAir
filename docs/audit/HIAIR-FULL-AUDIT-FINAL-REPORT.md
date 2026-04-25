# HiAir Full Audit Final Report

## 1. Executive Summary

HiAir is a late-MVP / pre-beta project with substantial backend, iOS, Android, CI, QA, release, and legal scaffolding already present.

- Current status: NEAR-GO for local engineering beta, NO-GO for public launch.
- Already ready: backend unit tests, Android debug/release/lint, iOS simulator build after fix.
- Not ready: DB-backed smoke on this machine, real-device QA, push notification E2E, signed store uploads, final legal/store/account evidence.
- Fixed in this pass: protected-env ops token fail-closed behavior, iOS missing source membership, Android backup risk, backend docs/security wording.
- Closed beta: NEAR-GO, not GO, because DB/preflight and external beta gates are unresolved.
- Public launch: NO-GO.

Main blockers: BLOCKED_BY_ENV local Postgres/API runtime; BLOCKED_EXTERNAL Apple/Google/store/secrets/push/payment; LEGAL_SIGNOFF_REQUIRED privacy/terms/GDPR/store labels.

## 2. Project Scope Found

| Area | Path | Found | Notes |
|---|---|---|---|
| Backend | `backend` | DONE | FastAPI, SQL, scripts, tests |
| iOS | `mobile/ios` | DONE | Xcode project and XcodeGen spec |
| Android | `mobile/android` | DONE | Gradle app |
| Docs | `docs` | DONE | Strategy, QA, release, legal, operator docs |
| Scripts | `backend/scripts`, `mobile/scripts` | DONE | Backend gates and release manifest |
| CI | `.github/workflows` | DONE | Backend, Android, iOS, external blocker workflows |
| Release artifacts | `docs/release-artifacts-manifest.md` | PARTIAL | iOS IPA missing |
| Legal/privacy | `docs/privacy-policy-draft.md`, `docs/terms-of-service-draft.md` | PARTIAL | Drafts only |
| Store metadata | `docs/store-metadata-packet.md` | PARTIAL | Contains TBDs/unchecked items |

## 3. Strategic Plan Status

| Phase | Planned | Current status | Gap | Verdict |
|---|---|---|---|---|
| Phase 1 - Research & Planning | Personas, APIs, wellness scope, architecture | Docs exist | Legal wording still draft | NEAR-GO |
| Phase 2 - MVP Development | Backend/mobile MVP flows | Core backend/mobile present; builds/tests pass | Notification E2E and device QA incomplete | NEAR-GO |
| Phase 3 - Beta Testing & Launch Preparation | TestFlight/Play internal, QA, legal/store prep | CI/docs/checklists exist | DB smoke/API preflight and external gates unresolved | NEAR-GO |
| Phase 4 - Public Launch & Growth | Store launch, support, monitoring | Runbooks/drafts exist | Legal/store/ops not closed | NO-GO |
| Phase 5 - Wearable & Premium | HealthKit/Health Connect, premium | Not in MVP; subscription scaffold only | Post-beta work | NO-GO |
| Phase 6 - Advanced Expansion | ML/B2B/smart home/community | Not implemented | Future roadmap | NO-GO |

## 4. What Is Already Done

| Area | Done evidence | Status |
|---|---|---|
| Backend tests | `30 passed` | DONE |
| Android build/lint | `BUILD SUCCESSFUL` for debug/release/lint | DONE |
| iOS simulator build | Build passed after project fix | FIXED |
| API auth | Mobile clients use bearer headers | DONE |
| Privacy endpoints | Export/delete endpoints exist | DONE |
| Release docs | Manifest, runbook, notes template, store packet exist | PARTIAL |

## 5. What Is Not Done

| Area | Missing item | Impact | Required action | Status |
|---|---|---|---|---|
| Backend env | Running Postgres/API for smoke/preflight | Beta evidence incomplete | Provision DB and run scripts | BLOCKED_BY_ENV |
| iOS | APNs registration, signed upload | TestFlight incomplete | Wire push and upload via ASC | BLOCKED_EXTERNAL |
| Android | FCM token flow, signed/internal upload | Play test incomplete | Wire FCM and upload | BLOCKED_EXTERNAL |
| Legal | Final privacy/terms/controller | Store/public blocked | Legal signoff | LEGAL_SIGNOFF_REQUIRED |
| Store | Screenshots, URLs, privacy labels | Store submission blocked | Finalize metadata | BLOCKED_EXTERNAL |

## 6. Backend Readiness

Endpoints are broad and cover auth, profiles, dashboard, planner, environment, risk, air, alerts, settings, symptoms, recommendations, notifications, subscriptions, privacy, observability, validation, and health. Tests pass. Auth/JWT and protected-env guards are in good shape after the ops-token fix. Data, smoke, retention, and beta preflight still need a live DB/API environment. Notifications and subscriptions remain PARTIAL for real provider E2E.

## 7. iOS Readiness

iOS simulator build now passes. Screens for auth/onboarding/dashboard/planner/symptom/settings exist. API uses bearer auth and configurable base URL. Notifications are MISSING at app registration/device-token permission level. TestFlight is BLOCKED_EXTERNAL by signing/account/upload and NEEDS_MANUAL_QA on device.

## 8. Android Readiness

Android debug/release/lint pass. API base URL is build-type based and release cleartext is disabled. Android backup is now disabled. FCM token registration and Android notification permission strategy are MISSING. Play Internal Test is BLOCKED_EXTERNAL by console/signing/metadata.

## 9. API Contract Readiness

iOS/backend and Android/backend paths largely match. Bearer auth matches. Risk enum compatibility is handled. Legacy auth is not used by mobile clients and is disabled by default. Base URL centralization exists. Mobile calls to ops-gated observability endpoints are a RISK until product/security decide whether those views are internal-only.

## 10. Security Readiness

Fixed: protected-env ops token guard, regression test, Android backup risk, stale docs. Remaining risks: production secret governance, APNs/FCM/payment credentials, mobile secure token storage, deployment WAF/rate limiting, real-provider webhook proof.

## 11. Privacy / GDPR Readiness

Engineering export/delete exists, and retention cleanup exists but was not DB-verified locally. Privacy Policy and Terms are drafts. Store privacy labels and Data Safety are draft/incomplete. Legal signoff is required before public launch.

## 12. QA / CI / Release Readiness

CI workflows exist. Local verification passed for backend tests, Android, and iOS simulator. Release manifest generation is PARTIAL: Android artifacts and iOS archive found, iOS IPA missing. Store handoff remains BLOCKED_EXTERNAL.

## 13. Fixes Applied

| File | Fix | Verification | Status |
|---|---|---|---|
| `backend/app/api/deps.py` | Protected env ops token fails closed | Backend pytest | FIXED |
| `backend/tests/test_security_runtime_policies.py` | Added regression test | `30 passed` | DONE |
| `backend/scripts/check_env_security.py` | Updated warning text | Strict safe-env check passed | FIXED |
| `backend/README.md` | Updated migration/auth docs | Review | FIXED |
| `mobile/android/app/src/main/AndroidManifest.xml` | Disabled backup | Android build/lint | FIXED |
| `mobile/ios/HiAir.xcodeproj/project.pbxproj` | Added `HiAirV2Theme.swift` source | iOS build passed | FIXED |

## 14. Remaining Internal Blockers

| Blocker | Impact | Recommended fix | Priority |
|---|---|---|---|
| Mobile observability endpoints are ops-gated | User-facing settings screens may fail | Split user-safe AI summary endpoint or remove from app | high |
| Push registration not wired in mobile apps | Notification E2E impossible | Add APNs/FCM token registration and permission flows | high |
| Android onboarding/auth flow uneven | Beta UX risk | Align with iOS onboarding/auth gate | medium |
| Secure mobile token storage | Public launch security risk | Move to Keychain/EncryptedSharedPreferences | medium |

## 15. Remaining External Blockers

| Blocker | Required owner/action | Why blocked | Priority |
|---|---|---|---|
| Apple Developer account | Account owner | Required for signing/TestFlight | high |
| App Store Connect access | Release owner | Required for upload/metadata | high |
| Google Play Console access | Release owner | Required for internal testing | high |
| Production secrets | Ops owner | Required for protected env | high |
| APNs/FCM credentials | Mobile/Ops owner | Required for live push | high |
| Legal Privacy Policy signoff | Legal owner | Store/public requirement | high |
| Terms signoff | Legal owner | Store/public requirement | high |
| GDPR contact/controller | Legal/Ops owner | Privacy compliance requirement | high |
| Payment provider credentials | Product/Ops owner | Required if premium is enabled | medium |
| Ops/on-call owner | Ops owner | Production/beta incident ownership | high |

## 16. Final Go / No-Go

| Target | Verdict | Why |
|---|---|---|
| Local MVP | NEAR-GO | Core builds/tests pass; DB smoke blocked locally |
| Backend | NEAR-GO | Tests pass; DB/preflight env blocked |
| iOS simulator | GO | Build passed after source membership fix |
| iOS real device | BLOCKED_EXTERNAL | Signing/device QA not verified |
| Android debug | GO | Build passed |
| Android release | GO | Release APK build passed; signed store artifact not verified |
| Closed Beta | NEAR-GO | Meets many engineering gates but DB/preflight, push, real-device, legal/store blockers remain |
| TestFlight | BLOCKED_EXTERNAL | Needs Apple account/signing/upload |
| Google Play Internal Test | BLOCKED_EXTERNAL | Needs Play Console/signing/upload |
| Public Launch | NO-GO | Legal/store/production ops/real-device evidence not closed |

## 17. Next 7-Day Execution Plan

### Day 1 - Backend/env/security closure

- tasks: provision staging Postgres/API; set strong env vars; run `init_db`, `smoke_db_flow`, `retention_cleanup --dry-run`, `beta_preflight`.
- expected deliverables: green backend gate evidence.
- verification command/evidence: backend script logs and DB smoke output.

### Day 2 - API contract/mobile fixes

- tasks: resolve mobile observability access policy; verify all endpoint responses with real API.
- expected deliverables: updated mobile/API contract notes.
- verification command/evidence: mobile API smoke on simulator/emulator.

### Day 3 - iOS device QA/TestFlight preparation

- tasks: wire APNs registration plan, run real-device QA, archive with signing.
- expected deliverables: TestFlight-ready archive or blocker evidence.
- verification command/evidence: Xcode archive/upload logs.

### Day 4 - Android device QA/Play Internal preparation

- tasks: wire FCM token flow or document stub beta scope, run real-device QA, generate signed AAB.
- expected deliverables: internal-test-ready AAB.
- verification command/evidence: signed AAB and QA report.

### Day 5 - Notifications/subscriptions/privacy verification

- tasks: verify device token, dispatch attempts, subscription stub/Stripe decision, export/delete after real data.
- expected deliverables: E2E notification/privacy evidence.
- verification command/evidence: API logs and delivery-attempt/export/delete proof.

### Day 6 - Store metadata/legal package

- tasks: finalize URLs, screenshots, Data Safety, privacy labels, legal review package.
- expected deliverables: completed store metadata packet.
- verification command/evidence: `check_store_metadata_packet.py` pass and legal signoff artifacts.

### Day 7 - Final go/no-go and beta handoff

- tasks: rerun full gates, update reports, assign on-call, decide beta scope.
- expected deliverables: signed go/no-go packet.
- verification command/evidence: CI/local command outputs and owner approvals.
