# Push E2E Launch Packet

Status: BLOCKED_EXTERNAL

## iOS APNs

- Required capability: Push Notifications enabled for `com.hiair.app`.
- Background modes: not required for basic alert receipt unless future background processing is added.
- APNs key/cert: BLOCKED_EXTERNAL.
- Bundle ID must match App Store Connect and APNs configuration.
- Physical device required; simulator does not provide production APNs delivery proof.
- Expected backend payload:

```json
{
  "platform": "ios",
  "device_token": "<apns-token-hex>",
  "profile_id": "<optional-profile-id>"
}
```

- Expected logs: `/api/notifications/device-token` success and later delivery attempt row.

## Android FCM

- Firebase project setup: BLOCKED_EXTERNAL.
- `google-services.json` policy: may be used locally/CI through secure channel; do not commit real production Firebase config without owner approval.
- Dependency/plugin requirements: add Firebase Messaging only when project config path is approved.
- Token generation path: app currently supports permission and backend upload for cached token; live generation requires Firebase config.
- Android 13 permission: `POST_NOTIFICATIONS` declared and requested.
- Physical/emulator behavior: token generation requires Google Play services and Firebase config.
- Expected backend payload:

```json
{
  "platform": "android",
  "device_token": "<fcm-token>",
  "profile_id": "<optional-profile-id>"
}
```

## Backend

- Provider mode:
  - `stub`: records dry-run behavior.
  - `live`: sends through APNs/FCM adapters.
- Env vars needed:
  - `NOTIFICATIONS_PROVIDER_MODE`
  - `NOTIFICATION_ADMIN_TOKEN`
  - FCM credentials (`FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY` or legacy key)
  - APNs credentials (`APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`, `APNS_TOPIC` or static token mode)
- Provider health endpoint: `GET /api/notifications/provider-health` with `X-Admin-Token`.
- Credentials health endpoint: `GET /api/notifications/credentials-health` with `X-Admin-Token`.
- Delivery attempts: `GET /api/notifications/delivery-attempts` with bearer auth.

## QA

| Step | Platform | Expected result | Evidence |
| ---- | -------- | --------------- | -------- |
| Login user | iOS/Android | Bearer token exists | Screenshot/API log |
| Accept permission | iOS | APNs registration requested | Device screen + app log |
| Accept permission | Android 13+ | Permission granted | Device screen |
| Upload token | iOS | Backend stores APNs token | API log/DB row |
| Upload token | Android | Backend stores FCM token | API log/DB row |
| Dispatch high-risk alert | Both | Notification delivered or provider error recorded | Delivery attempt log |
| Deny permission | Both | App remains usable | QA note |
