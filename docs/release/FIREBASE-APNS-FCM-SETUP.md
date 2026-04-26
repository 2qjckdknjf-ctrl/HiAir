# Firebase / APNs / FCM Setup

**Do not commit:** `google-services.json`, `GoogleService-Info.plist` (environment-specific), APNs `.p8` private keys, FCM service account JSON with send permissions, or any production API keys. Store only in a private secret manager or local files excluded by `.gitignore`.

Status: BLOCKED_EXTERNAL until the owner provides Firebase access, APNs credentials, app identifiers, and physical-device QA evidence.

## 1. Firebase Project

1. Sign in to Firebase Console.
2. Create or select the HiAir beta project.
3. Confirm project owner/admin access.
4. Save evidence: Firebase project overview screenshot.

## 2. Android App

1. Add an Android app to the Firebase project.
2. Use the exact Android package name from the repo.
3. Download `google-services.json`.
4. Place it only in the local Android app location required by the build setup or inject it through secret-managed CI.
5. Do not commit `google-services.json`.

Expected evidence:

- Android app registered in Firebase.
- FCM sender/project identifiers visible in Firebase.
- Local build can generate or receive an FCM token on a physical device.

## 3. iOS App

1. Add an iOS app to the Firebase project.
2. Use the exact iOS Bundle ID from Apple Developer and the Xcode target.
3. Download `GoogleService-Info.plist` only if the iOS implementation requires Firebase SDK configuration.
4. Do not commit real environment-specific Firebase files unless the team explicitly approves public non-secret config.

Expected evidence:

- iOS app registered in Firebase.
- Bundle ID matches Apple Developer and Xcode.

## 4. APNs Credentials

1. In Apple Developer, create or select an APNs Auth Key or certificate.
2. Upload the APNs key/cert to Firebase Cloud Messaging for the iOS app.
3. Store APNs Key ID, Team ID, and private key in the owner secret manager.
4. Do not commit APNs private keys.

Expected evidence:

- Firebase shows APNs credentials configured.
- Apple Developer shows Push Notifications enabled for the Bundle ID.

## 5. Backend Environment

Configure notification secrets in the deployment secret manager only. Use local/stub values for local smoke.

Required owner decisions:

- Production notification provider mode.
- Admin token value and rotation owner.
- APNs/FCM credential source.
- Notification retry/retention policy.

Local smoke remains:

```text
NOTIFICATIONS_PROVIDER_MODE=stub
NOTIFICATION_ADMIN_TOKEN=local-admin-token-change-me
RETENTION_DRY_RUN=true
```

## 6. Test Push Flow

1. Install iOS app on a physical device through Xcode or TestFlight.
2. Accept notification permission.
3. Confirm APNs token registration reaches the backend.
4. Install Android app on a physical device through Android Studio or Play Internal.
5. Accept Android 13+ notification permission if prompted.
6. Confirm FCM token registration reaches the backend.
7. Trigger a backend notification attempt in safe beta mode.
8. Confirm delivery on device and backend delivery-attempt logs.

## 7. Expected Evidence

| Area | Evidence |
| ---- | -------- |
| Firebase project | Project overview screenshot |
| Android FCM | Firebase Android app screenshot and device token upload log |
| iOS APNs | Apple capability screenshot, Firebase APNs credential screenshot, token upload log |
| Backend | Notification provider health endpoint and delivery-attempt record |
| Device delivery | Screenshot or screen recording of delivered push on each platform |

## 8. Security Rules

- Do not commit production secrets.
- Do not paste APNs private keys into docs.
- Do not commit `google-services.json` or `GoogleService-Info.plist` unless the owner explicitly approves the repository policy.
- Store live secrets in deployment secret management, not in `.env.local`.
