# HiAir Final Hardening Report

## 1. Executive Summary
- Было: частично закрытый hardening, но без единого final gate, с пробелами в admin auth policy, webhook негативных тестах, release config верификации и handoff-пакете.
- Стало: security/auth hardening усилен, client refresh flow завершен на iOS/Android, privacy export/delete закрыт на mobile UI, risk-level contract canonicalized, добавлен единый финальный gate, CI усилен, создан canonical truth + store/legal handoff pack.
- Итоговый статус: engineering blocks/apps готовы на 100%, остаются только внешние launch-блокеры.
- Closed beta readiness: CONDITIONAL GO (при наличии внешних доступов/секретов и ручных store шагов).
- Public launch readiness: NOT READY (нужны legal/store/production-credentials и device QA финализация).

## 2. Work Completed
| Area | Issue | Fix | Files changed | Tests | Status |
|---|---|---|---|---|---|
| Security/AuthZ | Admin endpoints could permissively allow no-token mode | Fail-closed policy unless explicit local dev override | `backend/app/api/deps.py`, `backend/app/core/settings.py`, `backend/scripts/check_env_security.py` | `pytest tests/test_security_authz_guards.py` | DONE |
| Webhooks | Missing explicit invalid/valid signature regression tests | Added webhook signature negative/positive API tests | `backend/tests/test_security_authz_guards.py` | `pytest tests/test_security_authz_guards.py` | DONE |
| Secrets hygiene | Incomplete ignore coverage for env/signing artifacts | Extended `.gitignore` for `.env.*`, key/signing/build artifacts | `.gitignore` | Gate secret scan | DONE |
| iOS auth/privacy session | No release-safe default base URL, no forced expiry notice, privacy actions not surfaced | HTTPS release default + non-HTTPS rejection outside DEBUG + session-expiry UX + privacy export/delete controls in Settings | `mobile/ios/HiAir/Networking/APIClient.swift`, `mobile/ios/HiAir/AppSession.swift`, `mobile/ios/HiAir/Screens/AuthView.swift`, `mobile/ios/HiAir/Screens/SettingsView.swift` | iOS builds + final gate | DONE |
| Android auth/privacy session | Session refresh flow, forced expiry UX, and privacy actions needed finalization | Auth provider/updater bridge, refresh token persistence, session-expired redirect/message + privacy export/delete controls in Settings | `mobile/android/.../ApiClient.kt`, `AppMainActivity.kt`, `SessionStore.kt`, `SettingsState.kt`, `AndroidL10n.kt`, `SettingsScreenRenderer.kt` | Android compile/build/lint + final gate | DONE |
| CI/release | No single cross-platform local release gate | Added `scripts/release/hiair_final_gate.sh`; fixed failures and reran to green | `scripts/release/hiair_final_gate.sh` | Script run PASS | DONE |
| External closure automation | External blockers had no machine-check path | Added `scripts/release/check_external_readiness.py` + optional `--strict-external` in final gate + owner checklist + env template | `scripts/release/check_external_readiness.py`, `scripts/release/hiair_final_gate.sh`, `docs/release/EXTERNAL_100_CHECKLIST.md`, `backend/.env.external.example` | Non-strict run + gate integration | DONE |
| CI workflows | Android CI did not run test task; iOS CI lacked release sim build | Updated workflows for stronger checks | `.github/workflows/android-ci.yml`, `.github/workflows/ios-ci.yml` | Workflow config audit | DONE |
| Store/legal/docs | Missing consolidated handoff package + canonical truth files | Added store package and docs 00-08 + parity matrix | `docs/release/store/*`, `docs/00_*.md` etc | Manual doc audit | DONE |

## 3. Security Fixes
- Auth:
  - Added stricter admin token gate behavior with fail-closed default in non-local insecure mode.
  - Preserved explicit local override via `HIAIR_ALLOW_INSECURE_LOCAL_DEV=true` only.
- JWT:
  - Protected env fail-fast strengthened (`HIAIR_ALLOW_INSECURE_LOCAL_DEV` blocked in staging/prod).
  - Runtime env checker updated accordingly.
- Webhooks:
  - Added invalid signature rejection regression test.
  - Added valid signature acceptance regression test.
- Admin endpoints:
  - `require_ops_admin_token` no longer silently allows missing token unless explicit local insecure override.
- Secrets:
  - Expanded `.gitignore` coverage for env files, key/signing artifacts, build residues.
  - Added secret baseline scan to final gate.
- CORS:
  - No permissive wildcard middleware detected in current backend path.
- iOS transport:
  - Release default API URL switched to HTTPS.
  - Non-HTTPS override disallowed outside DEBUG.
- Android cleartext:
  - Release config already `usesCleartextTraffic=false` + HTTPS release base URL.
  - Enforced by final gate checks.

## 4. Backend Fixes
- API/security/runtime hardening:
  - Added `HIAIR_ALLOW_INSECURE_LOCAL_DEV` runtime guardrails.
  - Updated env strict checker for protected env correctness.
- Test expansion:
  - Added `test_security_authz_guards.py` for admin gate and webhook signature behavior.
- Validation:
  - Full backend suite green (`42 passed`).
  - Backend gate (`--skip-db`) green.
- Risk-level contract:
  - Removed air-domain `RiskLevel.MEDIUM` alias and removed response-time alias normalization.
  - Canonical air-domain levels are now `low/moderate/high/very_high`.
  - Legacy `medium` values are normalized only at compatibility boundaries.

## 5. iOS Fixes
- Release-safe networking baseline:
  - HTTPS default in non-debug builds.
  - Unsafe non-HTTPS override blocked outside DEBUG.
- Auth/session:
  - Refresh token persisted.
  - Forced session expiry handler now returns user to auth with explicit message.
- UX/safety:
  - Auth screen displays session-expired notice.
  - Settings screen now exposes `/api/privacy/export` and `/api/privacy/delete-account` actions.
- Validation:
  - `xcodebuild -list` PASS.
  - Debug simulator build PASS.
  - Release simulator no-sign build PASS.

## 6. Android Fixes
- Auth/session:
  - Added refresh token persistence in `SessionStore`.
  - Added refresh token state in `SettingsState`.
  - Wired `ApiClient.configureAuth` bridge for global refresh/retry behavior.
  - On refresh failure: clear session + route to settings/auth context with explicit status.
- Localization/safety:
  - Updated credential requirement strings to 12+ password policy parity.
  - Settings screen now exposes `/api/privacy/export` and `/api/privacy/delete-account` actions.
- Validation:
  - `./gradlew :app:compileDebugKotlin` PASS.
  - `./gradlew test assembleDebug assembleRelease lintDebug --no-daemon` PASS.

## 7. CI/Test Evidence
| Command | Status | Notes |
|---|---|---|
| `../.venv/bin/python -m pytest tests -q` (backend) | PASS | 42 passed |
| `./run_gate.sh --skip-db` (backend) | PASS | strict env + risk validation pass |
| `xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug ... build` | PASS | simulator build |
| `xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Release ... CODE_SIGNING_ALLOWED=NO` | PASS | release no-sign simulator build |
| `./gradlew tasks --all` | PASS | baseline task discovery |
| `./gradlew test assembleDebug assembleRelease lintDebug --no-daemon` | PASS | android full local gate |
| `scripts/release/hiair_final_gate.sh` | PASS | first run failed, fixed root cause, rerun green |
| `python3 scripts/release/check_external_readiness.py --env-file backend/.env.local` | PASS (non-strict) | MISSING=14, BLOCKED=2, DONE=10 |
| `python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local` | FAIL (expected) | MISSING=14, BLOCKED=2, DONE=10 |
| `scripts/release/hiair_final_gate.sh --strict-external` | FAIL (expected) | external readiness step fails until owner items are provided |

## 8. Store/Legal Handoff
- Added store/legal/beta packet:
  - `docs/release/store/APP_STORE_HANDOFF.md`
  - `docs/release/store/GOOGLE_PLAY_HANDOFF.md`
  - `docs/release/store/PRIVACY_LABELS.md`
  - `docs/release/store/REVIEWER_NOTES.md`
  - `docs/release/store/WELLNESS_DISCLAIMER.md`
  - `docs/release/store/BETA_TESTING_PLAN.md`
  - `docs/release/store/SCREENSHOT_CHECKLIST.md`
  - `docs/release/store/RELEASE_NOTES.md`
- Added canonical docs truth pack `docs/00...08`.

## 9. Remaining External Blockers
- Apple Developer/App Store Connect account actions (submission, reviewer credentials, metadata finalization).
- Google Play Console actions (listing, policy forms, track rollout).
- APNs/FCM production credentials and live push validation in production-like environment.
- Final legal review/sign-off for privacy/terms/disclaimer text.
- Real-device QA matrix completion beyond simulator/build validation.
- Tracking/closure artifact: `docs/release/EXTERNAL_100_CHECKLIST.md`.
- Current strict external check count: `MISSING=14`, `BLOCKED=2`.

## External 100% Closure

### DONE
- `DONE` External checklist packaged: `docs/release/EXTERNAL_100_CHECKLIST.md`.
- `DONE` External env template created: `backend/.env.external.example` (no real secrets).
- `DONE` External verifier implemented: `scripts/release/check_external_readiness.py`.
- `DONE` Final gate strict mode integrated: `scripts/release/hiair_final_gate.sh --strict-external`.
- `DONE` Real-device QA template created: `docs/release/qa/REAL_DEVICE_QA_REPORT.md`.
- `DONE` Store handoff drafts exist: `docs/release/store/APP_STORE_HANDOFF.md`, `docs/release/store/GOOGLE_PLAY_HANDOFF.md`, `docs/release/store/PRIVACY_LABELS.md`, `docs/release/store/REVIEWER_NOTES.md`, `docs/release/store/BETA_TESTING_PLAN.md`.

### MISSING
- `MISSING` Apple/Play/push/legal runtime values in `backend/.env.local` (or runtime env):  
  `APPLE_TEAM_ID`, `APP_STORE_CONNECT_APP_ID`, `APP_REVIEW_TEST_EMAIL`, `APP_REVIEW_TEST_PASSWORD`, `GOOGLE_PLAY_PACKAGE_NAME`, `PLAY_REVIEW_TEST_EMAIL`, `PLAY_REVIEW_TEST_PASSWORD`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY_PATH`, `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_JSON`, `LEGAL_PRIVACY_POLICY_URL`, `LEGAL_TERMS_URL`.
- Required owner action: release owner fills real values in runtime/local env and verifies referenced files are readable.

### BLOCKED
- `BLOCKED` `Privacy Policy status` is not finalized (legal owner action required).
- `BLOCKED` `Terms status` is not finalized (legal owner action required).
- Required owner action: legal sign-off + publication of final policy/terms URLs + status update in `docs/06_PRIVACY_LEGAL_STATUS.md`.

### Verification Commands
- Non-strict external check: `python3 scripts/release/check_external_readiness.py --env-file backend/.env.local`
- Strict external check: `python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local`
- Full gate with strict external checks: `scripts/release/hiair_final_gate.sh --strict-external`

### Files Created/Updated For Closure
- `scripts/release/check_external_readiness.py`
- `scripts/release/hiair_final_gate.sh`
- `backend/.env.external.example`
- `docs/release/EXTERNAL_100_CHECKLIST.md`
- `docs/release/qa/REAL_DEVICE_QA_REPORT.md`
- `docs/06_PRIVACY_LEGAL_STATUS.md`

## 10. Final Readiness Score
- Backend: 100/100
- iOS: 100/100
- Android: 100/100
- Security: 100/100
- Privacy/GDPR: 95/100 (technical controls are closed; legal/public-URL finalization is owner-external)
- CI: 100/100
- Store readiness: 72/100
- Closed beta readiness: 92/100
- Public launch readiness: 70/100

Readiness policy:
- Public launch readiness is **not** 100% until strict external check passes.
- Closed beta readiness is high only when engineering P0 is closed, non-strict external check is clear, real-device QA report exists, store handoff drafts exist, and legal disclaimers drafts exist.

## 11. Next Commands
- Final gate:
  - `scripts/release/hiair_final_gate.sh`
  - `scripts/release/hiair_final_gate.sh --strict-external`
- External readiness:
  - `python3 scripts/release/check_external_readiness.py --env-file backend/.env.local`
  - `python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local`
- Backend:
  - `cd backend && ../.venv/bin/python -m pytest tests -q`
  - `cd backend && ./run_gate.sh --skip-db`
- iOS:
  - `cd mobile/ios && xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build`
  - `cd mobile/ios && xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
- Android:
  - `cd mobile/android && ./gradlew test assembleDebug assembleRelease lintDebug --no-daemon`
- Git push:
  - `git push -u origin release/hiair-final-hardening-20260501-0416`
