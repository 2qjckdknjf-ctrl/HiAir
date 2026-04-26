# Push readiness status (Closed Beta engineering view)

Last verified: **2026-04-26** (local gates on engineer machine).

## Summary

| Layer | Status | Notes |
| --- | --- | --- |
| Backend `POST /api/notifications/device-token` | **GO** | Bearer JWT via `get_current_user_id`; no admin token required |
| Backend provider dispatch | **stub / configurable** | `NOTIFICATIONS_PROVIDER_MODE`; live secrets external |
| iOS registration code | **GO** (compile + logic) | `UNUserNotificationCenter`, `registerForRemoteNotifications`, Keychain bearer, OSLog diagnostics |
| iOS simulator | **GO** build | APNs device token may be absent or unusable for push — expected |
| Android registration code | **GO** (compile + logic) | `POST_NOTIFICATIONS` on API 33+; **NO-OP** when no cached FCM token; `HiAirPush` log lines |
| Android without `google-services.json` | **GO** | No Google Services Gradle plugin; build does not require Firebase files |
| Android live FCM token | **NEAR-GO** (owner env) | With **local** gitignored `app/google-services.json`, Gradle enables `FcmFirebaseBootstrap` + token cache; delivery still **BLOCKED_EXTERNAL** until Firebase/backend live config |
| Push E2E (delivery) | **BLOCKED_EXTERNAL** | APNs/FCM credentials + physical devices |

## Contract (single upload endpoint)

All mobile clients use **`POST /api/notifications/device-token`** only for registration:

- iOS: `APIClient.registerDeviceToken` → `/api/notifications/device-token`
- Android: `ApiClient.registerDeviceToken` and `PushTokenRegistrar` / settings retry path → same path

## Log strings (diagnostics)

**iOS (OSLog, subsystem = bundle id, category `push`)**

- `Push: requesting notification authorization`
- `Push: permission granted; calling registerForRemoteNotifications` / permission denied messages
- `Push: token upload skipped — missing user id or bearer token`
- `Push: token upload attempted (platform=ios, token prefix=…)`
- `Push: token registered with backend (/api/notifications/device-token)`
- `Push: token upload failed — …`

**Android (`Log` tag `HiAirPush`)**

- `Push: requestPermissionAndRegister` / `POST_NOTIFICATIONS` request
- `Push: token upload skipped — missing session`
- `Push: NO-OP — no cached FCM token (…)`
- `Push: token upload attempted …`
- `Push: token registered with backend (/api/notifications/device-token)`
- `Push: token upload failed — …`
