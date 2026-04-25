# HiAir RC1 Real-Device QA Packet

Status: NOT_VERIFIED until run on physical iOS and Android devices.

## iOS Real-Device QA

- Install build through Xcode, TestFlight, or owner-approved internal distribution.
- Open app.
- Complete onboarding/profile.
- Signup/login.
- Verify dashboard loads.
- Verify risk card renders and updates.
- Verify planner screen.
- Log symptom.
- Verify settings.
- Verify logout/login persistence.
- Accept push permission.
- Verify APNs token upload reaches backend.
- Verify offline state.
- Verify delete/export if UI/API path is available.

## Android Real-Device QA

- Install build through Android Studio, `adb`, or Google Play Internal.
- Open app.
- Verify onboarding/auth gate.
- Signup/login.
- Verify dashboard loads.
- Verify risk card renders and updates.
- Verify planner screen.
- Log symptom.
- Verify settings.
- Verify logout/login persistence.
- Accept notification permission on Android 13+.
- Verify FCM token upload or no-op behavior when Firebase config is absent.
- Verify offline state.
- Verify delete/export if UI/API path is available.

## Execution Table

| Test | Device | Expected | Actual | Status | Evidence |
| ---- | ------ | -------- | ------ | ------ | -------- |
| iOS install | iPhone model / iOS version | app installs and opens | TBD | NOT_VERIFIED | screenshot/log |
| iOS onboarding/profile | iPhone model / iOS version | profile can be created | TBD | NOT_VERIFIED | screenshot |
| iOS auth | iPhone model / iOS version | signup/login works | TBD | NOT_VERIFIED | screenshot |
| iOS dashboard/risk/planner | iPhone model / iOS version | screens render with valid data | TBD | NOT_VERIFIED | screenshot |
| iOS symptoms/settings | iPhone model / iOS version | symptom log and settings work | TBD | NOT_VERIFIED | screenshot |
| iOS push | iPhone model / iOS version | permission prompt and APNs token upload observed | TBD | NOT_VERIFIED | backend/device log |
| Android install | Android model / OS version | app installs and opens | TBD | NOT_VERIFIED | screenshot/log |
| Android onboarding/auth gate | Android model / OS version | unauthenticated users are gated correctly | TBD | NOT_VERIFIED | screenshot |
| Android auth | Android model / OS version | signup/login works | TBD | NOT_VERIFIED | screenshot |
| Android dashboard/risk/planner | Android model / OS version | screens render with valid data | TBD | NOT_VERIFIED | screenshot |
| Android symptoms/settings | Android model / OS version | symptom log and settings work | TBD | NOT_VERIFIED | screenshot |
| Android notifications | Android model / OS version | Android 13+ permission and FCM token path verified | TBD | NOT_VERIFIED | backend/device log |
| Offline behavior | both platforms | app shows safe offline state | TBD | NOT_VERIFIED | screenshot |
| Delete/export | both platforms | privacy actions work if exposed in UI/API path | TBD | NOT_VERIFIED | screenshot/log |
