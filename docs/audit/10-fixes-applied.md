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

## Verification notes

- Backend tests: DONE
- Android debug/release/lint: DONE
- iOS simulator build: DONE
- DB smoke/preflight: BLOCKED_BY_ENV
- Store/legal/account checks: BLOCKED_EXTERNAL / LEGAL_SIGNOFF_REQUIRED
