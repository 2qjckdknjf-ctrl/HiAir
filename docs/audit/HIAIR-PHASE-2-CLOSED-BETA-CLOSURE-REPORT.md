# HiAir Phase 2 Closed Beta Closure Report

## 1. Executive Summary

- Starting status: NEAR-GO for closed beta with internal blockers around mobile observability, push registration, Android auth gating, mobile token storage, DB smoke, and iOS IPA export.
- Fixes applied in Phase 2: removed mobile observability calls, added iOS APNs registration path, added Android notification permission/token upload path, hardened mobile token storage, gated Android protected screens, added local smoke/IPA/store/legal runbooks.
- Current Closed Beta verdict: NEAR-GO.
- Current Public Launch verdict: NO-GO.

Closed beta is closer because P0/P1 internal code blockers are mostly closed or reduced to manual/external verification. It is not GO because DB smoke, real-device QA, live APNs/FCM, and store/legal gates remain unresolved.

## 2. Blocker Register Summary

| Type | Count | Notes |
|---|---:|---|
| INTERNAL_FIXABLE | 6 | P2-001, P2-002, P2-005, P2-006 fixed; P2-003/P2-004 partial pending live/manual QA |
| NEEDS_MANUAL_QA | 2 | Real-device iOS/Android QA |
| BLOCKED_BY_ENV | 1 | Local Postgres/API smoke |
| BLOCKED_EXTERNAL | 8 | Apple, Google, secrets, push live, payments, ops, WAF, IPA export |
| LEGAL_SIGNOFF_REQUIRED | 2 | Legal docs and store privacy/data safety |

## 3. P0/P1 Internal Blockers Closed

| ID | Area | Blocker | Fix | Verification | Status |
|---|---|---|---|---|---|
| P2-001 | API/Mobile | Mobile observability used ops endpoints | Removed mobile endpoint methods/cards; documented admin-only policy | `rg "/observability" mobile` no matches | FIXED |
| P2-002 | iOS Notifications | APNs registration missing | Added permission request, APNs callback, hex conversion, backend upload | iOS simulator build passed | FIXED |
| P2-005 | iOS Security | Token in `UserDefaults` | Moved token to Keychain with legacy migration | iOS simulator build passed | FIXED |
| P2-006 | Android Security | Token in plain preferences | Added Android Keystore AES/GCM encrypted token storage | Android build/lint passed | FIXED |
| P2-003 | Android Notifications | FCM token path missing | Added Android 13 permission strategy and backend upload for cached token | Android build/lint passed | PARTIAL |
| P2-004 | Android Auth | Protected screens accessible without auth | Gated dashboard/planner/symptoms to Settings/auth when no bearer session | Android build/lint passed | PARTIAL |

## 4. Remaining Internal Blockers

| ID | Area | Blocker | Why remains | Next action | Priority |
|---|---|---|---|---|---|
| P2-003 | Android Notifications | Live FCM token generation | Requires Firebase project config; code intentionally no-ops without token | Add Firebase Messaging after owner provides non-secret config path | P1_HIGH |
| P2-004 | Android UX | Dedicated onboarding parity | Minimal auth gate is implemented; full iOS parity needs UX decision | Add Android onboarding screen after beta UX review | P2_MEDIUM |

## 5. Remaining BLOCKED_BY_ENV

| ID | Area | Blocker | Exact required env/action | Command to verify |
|---|---|---|---|---|
| P2-007 | Backend Smoke | Local Postgres/API unavailable | Start local Postgres or Docker Compose and run backend with `backend/.env.local.example` | `cd backend && ../.venv/bin/python scripts/run_local_beta_smoke.sh` |

## 6. Remaining BLOCKED_EXTERNAL

| ID | Area | Blocker | Required owner | Required action |
|---|---|---|---|---|
| P2-008 | Release | iOS IPA missing | Apple/release owner | Provide signing and run IPA export |
| P2-011 | Push Live | APNs/FCM delivery proof missing | Mobile/Ops owner | Provide credentials/config and run push E2E |
| P2-012 | Apple | Developer/App Store Connect missing | Account owner | Grant access |
| P2-013 | Google Play | Console/signing upload missing | Account owner | Grant access |
| P2-014 | Secrets | Production secret governance missing | Ops owner | Configure secret manager and rotation evidence |
| P2-017 | Payments | Provider credentials missing if premium enabled | Product/Ops owner | Keep stub for beta or provide credentials |
| P2-018 | Ops | On-call owner not confirmed | Ops owner | Assign monitored rollout owner |
| P2-019 | Deployment | WAF/rate limiting not proven | Infra owner | Configure deployment protections |

## 7. LEGAL_SIGNOFF_REQUIRED

| ID | Document/Area | Required legal decision | Why needed |
|---|---|---|---|
| P2-015 | Privacy/Terms/GDPR | Approve final Privacy Policy, Terms, controller/contact, DSAR channel | Store/public distribution |
| P2-016 | Store privacy/data safety | Approve App Store privacy labels and Google Play Data Safety | Store submission |

## 8. Backend Verification

| Command | Result | Status |
|---|---|---|
| `cd backend && ../.venv/bin/python -m pytest -q` | `30 passed` | DONE |
| `cd backend && ../.venv/bin/python scripts/check_env_security.py --strict` | Fails in unmanaged local shell due missing env | BLOCKED_BY_ENV |
| strict env check with safe test env | Passed | DONE |
| `cd backend && ../.venv/bin/python scripts/validate_risk_historical.py` | `passed: True`, `4/4` cases | DONE |
| `cd backend && ../.venv/bin/python scripts/retention_cleanup.py --dry-run` | Local Postgres connection refused | BLOCKED_BY_ENV |
| `cd backend && ../.venv/bin/python scripts/beta_preflight.py` | API connection errors because server not running | BLOCKED_BY_ENV |

## 9. iOS Verification

| Command | Result | Status |
|---|---|---|
| `cd mobile/ios && xcodebuild -list -project HiAir.xcodeproj` | Scheme `HiAir` found | DONE |
| `cd mobile/ios && xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO` | `BUILD SUCCEEDED` | DONE |

## 10. Android Verification

| Command | Result | Status |
|---|---|---|
| `cd mobile/android && ./gradlew assembleDebug assembleRelease lint` | `BUILD SUCCESSFUL` | DONE |

## 11. API Contract Verification

| Area | Result | Status |
|---|---|---|
| Mobile observability | No `/observability` references in mobile clients | FIXED |
| Auth headers | Bearer auth remains mobile path | DONE |
| Device token endpoint | iOS/Android code paths call `/api/notifications/device-token` | PARTIAL |

## 12. Notifications Readiness

| Area | Result | Status |
|---|---|---|
| iOS registration code | Permission/APNs/backend upload path compiles | FIXED |
| Android registration code | Permission/backend upload path compiles; live token generation awaits Firebase config | PARTIAL |
| Live delivery | Requires APNs/FCM credentials and physical devices | BLOCKED_EXTERNAL |

## 13. Security Readiness

| Area | Result | Status |
|---|---|---|
| iOS token storage | Keychain with legacy migration | FIXED |
| Android token storage | Keystore-backed encrypted storage | FIXED |
| Backend tests | `30 passed` | DONE |
| Secret governance | Production proof absent | BLOCKED_EXTERNAL |

## 14. Store / Release Readiness

| Area | Result | Status |
|---|---|---|
| Release manifest | Android AAB/APK and iOS archive found; iOS IPA missing | PARTIAL |
| IPA export runbook | Added | DONE |
| Store metadata draft | Updated blockers and closure draft | PARTIAL |
| Privacy/Data Safety drafts | Added | LEGAL_SIGNOFF_REQUIRED |

## 15. Final Go / No-Go

| Target | Verdict | Why |
|---|---|---|
| Backend local tests | GO | Pytest passed |
| Backend DB smoke | BLOCKED_BY_ENV | No local Postgres/API runtime |
| iOS simulator | GO | Build passed |
| iOS real device | NOT_VERIFIED | Needs signing/device QA |
| Android debug | GO | Build passed |
| Android release | GO | Release build passed |
| Push registration code | NEAR-GO | iOS fixed; Android local-safe path partial pending Firebase token source |
| Push live delivery | BLOCKED_EXTERNAL | APNs/FCM credentials and devices required |
| Closed Beta | NEAR-GO | Internal blockers reduced; env/external/manual gates remain |
| TestFlight | BLOCKED_EXTERNAL | Apple signing/App Store Connect required |
| Google Play Internal Test | BLOCKED_EXTERNAL | Play Console/signing required |
| Public Launch | NO-GO | Legal/store/ops/live QA not closed |

## 16. Next Human Actions

1. Start local/staging Postgres and run `backend/scripts/run_local_beta_smoke.sh`.
2. Provide Apple Developer/App Store Connect access and run `docs/release/IOS-IPA-EXPORT-RUNBOOK.md`.
3. Provide Firebase/APNs config and execute `docs/notifications/PUSH-E2E-QA-CHECKLIST.md`.
4. Complete legal review for privacy, terms, App Store privacy labels, and Google Play Data Safety.
5. Assign an ops/on-call owner for monitored closed beta rollout.
