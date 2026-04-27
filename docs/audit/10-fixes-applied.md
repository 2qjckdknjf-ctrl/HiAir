# Fixes Applied

| File | Problem | Fix | Verification | Status |
|---|---|---|---|---|
| `backend/app/api/deps.py` | Ops endpoints could pass with missing admin token in protected envs | Added protected-env fail-closed behavior | `pytest tests/test_security_runtime_policies.py -q`, full pytest | FIXED |
| `backend/tests/test_security_runtime_policies.py` | No regression test for protected-env ops token behavior | Added test for staging with empty admin token | `3 passed`; full suite `30 passed` | DONE |
| `backend/scripts/check_env_security.py` | Warning text said endpoints were unprotected, no longer accurate for protected envs | Updated warning wording | strict env check with safe env passed | FIXED |
| `backend/README.md` | Migration docs listed only first two SQL files; auth examples suggested fallback auth | Documented all SQL files and bearer-token default | Documentation review | FIXED |
| `mobile/android/app/src/main/AndroidManifest.xml` | Android backup enabled while app stores session state | Set `android:allowBackup="false"` | `./gradlew assembleDebug assembleRelease lint` passed | FIXED |
| `mobile/ios/HiAir.xcodeproj/project.pbxproj` | `HiAirV2Theme.swift` existed but was not in target sources, breaking iOS build | Added file reference and source build phase entry | iOS simulator build passed | FIXED |
| `mobile/ios/HiAir/KeychainStore.swift` | iOS bearer token was stored in `UserDefaults` | Added Keychain wrapper and token migration | iOS simulator build passed | FIXED |
| `mobile/ios/HiAir/PushRegistrationService.swift` | iOS APNs permission/registration flow missing | Added permission request, APNs callback, token hex conversion, backend upload | iOS simulator build passed | FIXED |
| `mobile/android/app/src/main/java/com/hiair/SessionStore.kt` | Android bearer token was stored in plain app preferences | Added Android Keystore-backed AES/GCM storage and migration | Android build/lint passed | FIXED |
| `mobile/android/app/src/main/java/com/hiair/PushTokenRegistrar.kt` | Android notification permission/token registration path missing | Added Android 13 permission strategy and local-safe backend token upload for cached token | Android build/lint passed | PARTIAL |
| `mobile/android/app/src/main/java/com/hiair/ui/navigation/RootShellState.kt` | Android protected tabs could open without bearer session | Gate protected navigation to Settings/auth when unauthenticated | Android build/lint passed | PARTIAL |
| `mobile/ios/HiAir/Networking/APIClient.swift` and Android `ApiClient.kt` | Mobile clients called ops-gated observability endpoints | Removed mobile observability endpoint methods and user-facing cards | `rg "/observability" mobile` returned no matches | FIXED |
| `backend/.env.local.example` and `backend/scripts/run_local_beta_smoke.sh` | Local DB smoke path lacked exact no-secret bootstrap | Added safe local env example and helper script | DB execution still blocked by local Postgres | PARTIAL |
| `docs/api/MOBILE-OBSERVABILITY-ACCESS-POLICY.md` | Missing policy for admin observability | Documented `/api/observability/*` as internal-only | Mobile grep passed | DONE |
| `docs/notifications/PUSH-REGISTRATION-IMPLEMENTATION.md` | Push implementation status undocumented | Added platform implementation notes and external blockers | Documentation review | DONE |
| `docs/security/MOBILE-TOKEN-STORAGE-HARDENING.md` | Mobile token hardening status undocumented | Added iOS/Android storage details and QA caveats | Documentation review | DONE |
| `docs/audit/*` | Required audit reports missing | Added audit report package | Files created | DONE |
| `mobile/ios/HiAir/PushRegistrationService.swift` | Push path lacked operator-visible diagnostics | Added `OSLog` messages for permission, upload attempt, success, failure | iOS `xcodebuild` simulator build | DONE |
| `mobile/android/.../PushTokenRegistrar.kt` | Silent skip when no FCM token / HTTP failures | Added `HiAirPush` `Log` lines; explicit NO-OP message without Firebase | `./gradlew :app:compileDebugKotlin` | DONE |
| `mobile/scripts/generate_release_manifest.py` | RC policy for IPA not spelled in manifest | Added `--rc` flag + Closed Beta RC footer (IPA `BLOCKED_EXTERNAL` when absent) | `python3 mobile/scripts/generate_release_manifest.py --rc` | DONE |
| `docs/audit/*`, `docs/notifications/*`, `docs/release/*` (Phase 18) | Delta audit + RC packet requested | Added ledger, deep delta, GO/NO-GO, push readiness/runbook/matrix, RC artifact/upload docs | This audit pass | DONE |
| `backend/app/services/environment_service.py` | `datetime.utcnow()` deprecation warnings in pytest | Use `datetime.now(UTC)` for mock snapshot | `pytest -q` | DONE |
| `mobile/ios/HiAir/AppSession.swift` | Push registration status could survive logout | Remove `PushRegistrationService.lastStatusKey` on logout | iOS build | DONE |
| `mobile/android/.../SessionStore.kt` | Cached FCM token could survive logout | Clear `hiair_push` shared prefs in `clear()` | compileDebugKotlin | DONE |
| `docs/audit/20-dorabotka-plan.md` | Executable plan requested | Plan + status table | Review | DONE |
| `.gitignore` | Firebase plist/json could be committed by mistake | Ignore `app/google-services.json` and iOS `GoogleService-Info.plist` | Path check | DONE |
| `backend/scripts/run_local_beta_smoke.sh` | Preflight skipped without hint | Print optional uvicorn + beta_preflight one-liners | `bash -n` | DONE |
| `docs/mobile/ANDROID-FCM-LOCAL-INTEGRATION-STEPS.md` | FCM integration undocumented | Owner copy-paste Gradle + prefs contract | Review | DONE |
| `docs/release/HIAIR-CLOSED-BETA-RC1-ARTIFACTS.md` | Stale `30 passed` in living RC table | `36 passed` + drift note | Review | DONE |
| `mobile/android/build.gradle.kts` | FCM optional | `google-services` plugin `apply false` | Gradle | DONE |
| `mobile/android/app/build.gradle.kts` | Conditional Firebase | Plugin + BOM + messaging only if `google-services.json` exists; `BuildConfig.FIREBASE_CONFIGURED` | assembleDebug/Release | DONE |
| `mobile/android/app/src/firebase/.../FcmFirebaseBootstrap.kt` | No FCM token writer | Cache FCM token to `hiair_push` prefs when Firebase enabled | compile with json (manual) | DONE |
| `mobile/android/.../FcmTokenRefresher.kt` | Main code cannot import Firebase when disabled | Reflection bridge to bootstrap | assembleDebug without json | DONE |
| `mobile/android/.../PushTokenRegistrar.kt` | Upload before refresh | Run `FcmTokenRefresher` then read prefs / upload | lintDebug | DONE |
| `mobile/android/.../HiAirFirebaseMessagingService.kt` | FCM token rotation | `onNewToken` writes prefs; manifest stanza documented for local-only | clean assembleDebug | DONE |
| `mobile/ios/HiAir/PushRegistrationService.swift` | Foreground push / simulator diagnostics | `UNUserNotificationCenterDelegate`, `didFailToRegister…` | xcodebuild simulator | DONE |
| `docs/mobile/ANDROID-FCM-LOCAL-INTEGRATION-STEPS.md` | Service registration | Document `<service>` for MESSAGING_EVENT | Review | DONE |
| `docs/notifications/PUSH-E2E-RUNBOOK.md` | iOS delegate | Note foreground + simulator failure path | Review | DONE |
| `mobile/android/app/src/firebase/AndroidManifest.xml` | FCM service not in merged manifest | Overlay manifest merged when `google-services.json` exists | Gradle + merged_manifest grep (no JSON) | DONE |
| `mobile/android/app/build.gradle.kts` | `manifest.srcDir` API missing | Use `manifest.srcFile("src/firebase/AndroidManifest.xml")` | assembleDebug | DONE |
| `backend/scripts/run_backend_gate.py` | Gate без pytest / без .env.local | pytest + `--env-file` default + `--admin-token` + `--skip-pytest` | script review | DONE |
| `backend/README.md` | Gate docs stale | Document flags + CI parity | Review | DONE |
| `docs/qa/ENGINEERING-PRE-DEVICE-GATE-COMMANDS.md` | Pre-device QA commands scattered | Single copy-paste runbook | Review | DONE |
| `docs/task-backlog.md` | Next step order | Engineer gates before uploads | Review | DONE |

## Verification notes

- Backend tests: DONE
- Android debug/release/lint: DONE
- iOS simulator build: DONE
- DB smoke/preflight: BLOCKED_BY_ENV
- Store/legal/account checks: BLOCKED_EXTERNAL / LEGAL_SIGNOFF_REQUIRED
