# HiAir Final Hardening Report

## 1. Executive Summary
- Было: частично закрытый hardening, но без единого final gate, с пробелами в admin auth policy, webhook негативных тестах, release config верификации и handoff-пакете.
- Стало: security/auth hardening усилен, client refresh flow завершен на iOS/Android, добавлен единый финальный gate, CI усилен, создан canonical truth + store/legal handoff pack.
- Итоговый статус: engineering-ready для closed beta с внешними блокерами.
- Closed beta readiness: CONDITIONAL GO (при наличии внешних доступов/секретов и ручных store шагов).
- Public launch readiness: NOT READY (нужны legal/store/production-credentials и device QA финализация).

## 2. Work Completed
| Area | Issue | Fix | Files changed | Tests | Status |
|---|---|---|---|---|---|
| Security/AuthZ | Admin endpoints could permissively allow no-token mode | Fail-closed policy unless explicit local dev override | `backend/app/api/deps.py`, `backend/app/core/settings.py`, `backend/scripts/check_env_security.py` | `pytest tests/test_security_authz_guards.py` | DONE |
| Webhooks | Missing explicit invalid/valid signature regression tests | Added webhook signature negative/positive API tests | `backend/tests/test_security_authz_guards.py` | `pytest tests/test_security_authz_guards.py` | DONE |
| Secrets hygiene | Incomplete ignore coverage for env/signing artifacts | Extended `.gitignore` for `.env.*`, key/signing/build artifacts | `.gitignore` | Gate secret scan | DONE |
| iOS auth session | No release-safe default base URL and no forced expiry notice | HTTPS release default + non-HTTPS rejection outside DEBUG + session-expiry UX | `mobile/ios/HiAir/Networking/APIClient.swift`, `mobile/ios/HiAir/AppSession.swift`, `mobile/ios/HiAir/Screens/AuthView.swift` | iOS builds + final gate | DONE |
| Android auth session | Session refresh flow and forced expiry UX needed finalization | Auth provider/updater bridge, refresh token persistence, session-expired redirect/message | `mobile/android/.../ApiClient.kt`, `AppMainActivity.kt`, `SessionStore.kt`, `SettingsState.kt`, `AndroidL10n.kt` | Android compile/build/lint + final gate | DONE |
| CI/release | No single cross-platform local release gate | Added `scripts/release/hiair_final_gate.sh`; fixed failures and reran to green | `scripts/release/hiair_final_gate.sh` | Script run PASS | DONE |
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
  - Full backend suite green (`43 passed`).
  - Backend gate (`--skip-db`) green.
- Remaining backend architecture gap:
  - Risk-level alias complexity (`medium`/`moderate`) still present via compatibility layer; tracked as P1 cleanup.

## 5. iOS Fixes
- Release-safe networking baseline:
  - HTTPS default in non-debug builds.
  - Unsafe non-HTTPS override blocked outside DEBUG.
- Auth/session:
  - Refresh token persisted.
  - Forced session expiry handler now returns user to auth with explicit message.
- UX/safety:
  - Auth screen displays session-expired notice.
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
- Validation:
  - `./gradlew :app:compileDebugKotlin` PASS.
  - `./gradlew test assembleDebug assembleRelease lintDebug --no-daemon` PASS.

## 7. CI/Test Evidence
| Command | Status | Notes |
|---|---|---|
| `../.venv/bin/python -m pytest tests -q` (backend) | PASS | 43 passed |
| `./run_gate.sh --skip-db` (backend) | PASS | strict env + risk validation pass |
| `xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug ... build` | PASS | simulator build |
| `xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Release ... CODE_SIGNING_ALLOWED=NO` | PASS | release no-sign simulator build |
| `./gradlew tasks --all` | PASS | baseline task discovery |
| `./gradlew test assembleDebug assembleRelease lintDebug --no-daemon` | PASS | android full local gate |
| `scripts/release/hiair_final_gate.sh` | PASS | first run failed, fixed root cause, rerun green |

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

## 10. Final Readiness Score
- Backend: 90/100
- iOS: 86/100
- Android: 88/100
- Security: 90/100
- Privacy/GDPR: 82/100
- CI: 87/100
- Store readiness: 72/100
- Closed beta readiness: 85/100
- Public launch readiness: 70/100

## 11. Next Commands
- Final gate:
  - `scripts/release/hiair_final_gate.sh`
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
