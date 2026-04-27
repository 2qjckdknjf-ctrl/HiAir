# Android Real Device QA Script

Status: NEEDS_MANUAL_QA

## Preconditions

- APK/AAB-derived build installed on physical Android device.
- Staging API URL configured.
- Test account available.
- Firebase config available if push token generation is in scope.

## Test Script

| Step | Expected result | Status |
|---|---|---|
| Install/open | App launches without crash | NOT_VERIFIED |
| Onboarding/auth gate | Protected tabs route to Settings/auth when logged out | NOT_VERIFIED |
| Signup/login | Bearer session is created and persisted | NOT_VERIFIED |
| Dashboard | Dashboard opens after auth and refreshes API data | NOT_VERIFIED |
| Risk card | Risk card displays compatible low/medium/moderate/high values | NOT_VERIFIED |
| Planner | Planner refresh works | NOT_VERIFIED |
| Symptom log | Symptom submit works or safe error shown | NOT_VERIFIED |
| Settings | Settings load/save works | NOT_VERIFIED |
| Logout/login persistence | Logout clears encrypted session; login restores access | NOT_VERIFIED |
| Android 13+ notification permission | Permission prompt appears and denial is safe | NOT_VERIFIED |
| FCM token no-op/upload | No crash without token; upload works when token exists | NOT_VERIFIED |
| Offline state | App does not crash; user sees safe failure | NOT_VERIFIED |

## Evidence Required

- Device model/Android version.
- Build variant/version.
- Screenshots for core screens.
- Backend logs for auth/dashboard/symptoms/settings.
- Token upload/delivery logs if Firebase is configured.
