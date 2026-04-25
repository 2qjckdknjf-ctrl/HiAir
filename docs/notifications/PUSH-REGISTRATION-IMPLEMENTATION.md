# Push Registration Implementation

Status: PARTIAL

## Implemented in Phase 2

### iOS

- Added `PushRegistrationService`.
- Added `UNUserNotificationCenter` permission request.
- Added APNs registration via `UIApplication.shared.registerForRemoteNotifications()`.
- Added `HiAirAppDelegate` callback for APNs device tokens.
- Converts APNs token bytes to hex.
- Uploads token to `POST /api/notifications/device-token` with bearer auth.
- Simulator builds do not require APNs credentials.

### Android

- Added `POST_NOTIFICATIONS` permission for Android 13+.
- Added `PushTokenRegistrar`.
- Registers cached Android push token with `POST /api/notifications/device-token` when a token is available.
- Does not require `google-services.json` or real FCM credentials for local debug/release builds.

## Not implemented locally

- BLOCKED_EXTERNAL: real APNs team/key/topic credentials.
- BLOCKED_EXTERNAL: real FCM project credentials and `google-services.json`.
- NEEDS_MANUAL_QA: physical-device permission prompts and token receipt.

## Android FCM note

The current Android implementation is deliberately safe for local builds without Firebase project files. It provides permission strategy and backend upload path for an available token. Live FCM token generation should be enabled after the project owner supplies Firebase config; do not commit real `google-services.json` credentials.

## Verification

- iOS simulator build.
- Android `assembleDebug assembleRelease lint`.
- `rg "registerDeviceToken|device-token|registerForRemoteNotifications|POST_NOTIFICATIONS" mobile`
