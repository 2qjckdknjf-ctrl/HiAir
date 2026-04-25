# HiAir Phase 3 Beta Launch Preparation Report

## 1. Executive Summary

- Starting status: Closed Beta NEAR-GO after Phase 2, with DB smoke, real-device QA, live push, TestFlight/Google Play, legal/store, and ops gates still open.
- Work completed: backend local/staging smoke runbook and script, API local runbook, TestFlight packet, Google Play packet, iOS/Android real-device QA scripts, push E2E packet, store/legal metadata packet, ops runbook, and Phase 3 gate register.
- Current Closed Beta verdict: NEAR-GO.
- Current TestFlight verdict: BLOCKED_EXTERNAL.
- Current Google Play Internal verdict: BLOCKED_EXTERNAL.
- Current Public Launch verdict: NO-GO.

Phase 3 turned the remaining gates into exact owner-executable packets. Local engineering checks remain green for backend tests, iOS simulator, Android debug/release/lint, and Android bundleRelease. Backend DB smoke and API preflight remain BLOCKED_BY_ENV because no Postgres/API runtime is available in this environment.

## 2. Beta Launch Gate Register Summary

| Gate type | Count | Status |
| --------- | ----: | ------ |
| Local engineering GO | 5 | Backend tests, env strict with local example, iOS simulator, Android build/lint, Android bundleRelease |
| BLOCKED_BY_ENV | 3 | Backend DB smoke, API preflight, retention dry-run |
| NEEDS_MANUAL_QA | 3 | iOS real device, Android real device, APNs token proof |
| BLOCKED_EXTERNAL | 7 | TestFlight, Google Play, APNs/FCM live, Apple/Google access, secrets, ops owner, WAF/rate limiting |
| LEGAL_SIGNOFF_REQUIRED | 3 | Legal signoff, App Store privacy labels, Google Play Data Safety |
| READY_FOR_OWNER/PARTIAL | 2 | Store metadata, Android signed/upload path |

## 3. Backend Runtime / DB Smoke

| Item | Result | Status |
| ---- | ------ | ------ |
| `.env.local.example` | Updated with local-only beta smoke variables | DONE |
| `backend/docker-compose.local.yml` | Added local Postgres service | DONE |
| `backend/scripts/run_local_beta_smoke.sh` | Updated with DONE/BLOCKED_BY_ENV/FAILED statuses | DONE |
| DB reachability | Local Postgres connection refused | BLOCKED_BY_ENV |
| Env strict via smoke helper | Passed using `.env.local.example` | DONE |
| Historical risk validation | Passed 4/4 cases | DONE |
| API preflight | Skipped by helper because API server is not running | BLOCKED_BY_ENV |

## 4. iOS TestFlight Package

| Item | Result | Status |
| ---- | ------ | ------ |
| TestFlight packet | `docs/release/TESTFLIGHT-BETA-LAUNCH-PACKET.md` created | READY_FOR_OWNER |
| Export options template | `mobile/ios/ExportOptions.plist.template` created | READY_FOR_OWNER |
| iOS QA script | `docs/qa/IOS-REAL-DEVICE-QA-SCRIPT.md` created | READY_FOR_OWNER |
| iOS simulator build | Passed | GO |
| iOS archive/IPA | Requires Apple signing/App Store Connect | BLOCKED_EXTERNAL |

## 5. Android Google Play Internal Package

| Item | Result | Status |
| ---- | ------ | ------ |
| Google Play packet | `docs/release/GOOGLE-PLAY-INTERNAL-BETA-LAUNCH-PACKET.md` created | READY_FOR_OWNER |
| Android QA script | `docs/qa/ANDROID-REAL-DEVICE-QA-SCRIPT.md` created | READY_FOR_OWNER |
| `assembleDebug assembleRelease lint` | `BUILD SUCCESSFUL` | GO |
| `bundleRelease` | `BUILD SUCCESSFUL`; AAB generated | GO |
| Play upload | Requires Play Console/signing/tester setup | BLOCKED_EXTERNAL |

## 6. Push E2E Package

| Item | Result | Status |
| ---- | ------ | ------ |
| Push E2E launch packet | `docs/notifications/PUSH-E2E-LAUNCH-PACKET.md` created | READY_FOR_OWNER |
| iOS APNs registration code | Compiles in simulator build | NEAR-GO |
| Android notification path | Permission/backend upload path exists; live token generation needs Firebase config | PARTIAL |
| Live delivery proof | Requires APNs/FCM credentials and physical devices | BLOCKED_EXTERNAL |

## 7. Store / Legal / Metadata Package

| Item | Result | Status |
| ---- | ------ | ------ |
| Store/legal metadata packet | `docs/release/STORE-LEGAL-METADATA-LAUNCH-PACKET.md` created | READY_FOR_OWNER |
| App Store privacy draft | Existing draft referenced | LEGAL_SIGNOFF_REQUIRED |
| Google Play Data Safety draft | Existing draft referenced | LEGAL_SIGNOFF_REQUIRED |
| Final privacy/support URLs | Not available | BLOCKED_EXTERNAL |
| Legal approval | Not available | LEGAL_SIGNOFF_REQUIRED |

## 8. Ops / Monitoring Package

| Item | Result | Status |
| ---- | ------ | ------ |
| Closed beta ops runbook | `docs/ops/CLOSED-BETA-OPS-RUNBOOK.md` created | READY_FOR_OWNER |
| Beta owner | Unknown | BLOCKED_EXTERNAL |
| On-call owner | Unknown | BLOCKED_EXTERNAL |
| WAF/rate limiting evidence | Not available | BLOCKED_EXTERNAL |
| Daily beta review checklist | Documented | READY_FOR_OWNER |

## 9. Verification Results

| Area | Command | Result | Status |
| ---- | ------- | ------ | ------ |
| Backend tests | `cd backend && ../.venv/bin/python -m pytest -q` | `30 passed` | GO |
| Backend unmanaged env strict | `cd backend && ../.venv/bin/python scripts/check_env_security.py --strict` | Fails because local shell lacks env values | BLOCKED_BY_ENV |
| Backend historical risk | `cd backend && ../.venv/bin/python scripts/validate_risk_historical.py` | `passed: True`, `4/4` | GO |
| Backend local smoke helper | `cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh` | Env strict + historical validation DONE; Postgres/API BLOCKED_BY_ENV | BLOCKED_BY_ENV |
| iOS | `xcodebuild -list` + simulator build | Passed | GO |
| Android build/lint | `./gradlew assembleDebug assembleRelease lint` | `BUILD SUCCESSFUL` | GO |
| Android bundle | `./gradlew bundleRelease` | `BUILD SUCCESSFUL` | GO |
| Release manifest | `python3 mobile/scripts/generate_release_manifest.py --strict` | Android AAB/APK and iOS archive found; iOS IPA missing | PARTIAL |

## 10. Remaining Human Actions

| Action | Owner | Why required | Priority |
| ------ | ----- | ------------ | -------- |
| Start local/staging Postgres and API, rerun smoke/preflight | Backend/Ops owner | Required to close backend DB/API gates | P0 |
| Provide Apple Developer/App Store Connect access | Project owner | Required for iOS archive/IPA/TestFlight | P0 |
| Provide Google Play Console/signing path | Project owner | Required for Play Internal | P0 |
| Provide APNs/FCM credentials/config | Mobile/Ops owner | Required for live push E2E | P1 |
| Complete legal review and final URLs | Legal/Product owner | Required for store submission | P1 |
| Assign beta/on-call/support owner | Project owner | Required for monitored rollout | P1 |
| Configure deployment WAF/rate limiting evidence | Infra/Ops owner | Required before internet beta exposure | P1 |

## 11. Final Go / No-Go

| Target | Verdict | Why |
| ------ | ------- | --- |
| Backend tests | GO | `30 passed` |
| Backend DB smoke | BLOCKED_BY_ENV | Postgres unavailable |
| Backend API preflight | BLOCKED_BY_ENV | API server not running |
| iOS simulator | GO | Build passed |
| iOS real device | NOT_VERIFIED | Needs device/signing QA |
| iOS IPA export | BLOCKED_EXTERNAL | Apple signing/App Store Connect required |
| TestFlight | BLOCKED_EXTERNAL | Apple account/upload required |
| Android debug | GO | Build passed |
| Android release | GO | Build passed |
| Android bundleRelease | GO | AAB generated |
| Android real device | NOT_VERIFIED | Needs device QA |
| Google Play Internal | BLOCKED_EXTERNAL | Console/signing/upload required |
| Push code | NEAR-GO | iOS code compiles; Android live token generation awaits Firebase config |
| Push live E2E | BLOCKED_EXTERNAL | APNs/FCM credentials required |
| Store metadata | READY_FOR_OWNER | Draft packet exists; owner values missing |
| Legal | LEGAL_SIGNOFF_REQUIRED | Privacy/Terms/Data Safety need legal approval |
| Ops/on-call | BLOCKED_EXTERNAL | Owner assignment missing |
| Closed Beta | NEAR-GO | Engineering packages ready, runtime/external/manual gates remain |
| Public Launch | NO-GO | Legal/store/ops/live evidence incomplete |

## 12. Exact Next Owner Checklist

1. Copy `backend/.env.local.example` to `backend/.env.local`.
2. Start Postgres via Homebrew or `docker compose -f backend/docker-compose.local.yml up -d postgres`.
3. Run `cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh`.
4. Start API with `../.venv/bin/python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000`.
5. Run `scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"`.
6. Grant Apple Developer/App Store Connect access and run `docs/release/TESTFLIGHT-BETA-LAUNCH-PACKET.md`.
7. Grant Google Play Console/signing path and run `docs/release/GOOGLE-PLAY-INTERNAL-BETA-LAUNCH-PACKET.md`.
8. Provide Firebase/APNs configuration and execute `docs/notifications/PUSH-E2E-LAUNCH-PACKET.md`.
9. Complete legal review for privacy, terms, App Store privacy labels, and Google Play Data Safety.
10. Assign beta owner, on-call owner, support channel, and deployment WAF/rate-limit owner.
