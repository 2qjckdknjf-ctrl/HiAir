# Mobile Token Storage Hardening

Status: FIXED for local closed-beta builds.

## iOS

Phase 2 moved bearer token storage from `UserDefaults` to Keychain.

- New wrapper: `mobile/ios/HiAir/KeychainStore.swift`
- Keychain accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- One-time migration: existing `UserDefaults` token is copied into Keychain and then removed.
- Logout deletes the Keychain token.

## Android

Phase 2 moved bearer token storage out of plain shared preferences.

- Token encryption uses Android Keystore-backed AES/GCM.
- Session metadata (`email`, `user_id`) remains in private app preferences.
- Legacy plain `access_token` is migrated into encrypted storage and removed.
- Manifest backup is disabled.

## Remaining public-launch hardening

- NEEDS_MANUAL_QA: verify logout clears token on physical iOS/Android devices.
- NEEDS_MANUAL_QA: verify app reinstall/update migration path.
- RISK: consider biometric/key invalidation policy only if product requires stronger local auth.

## Delta (2026-04-26)

- Push flows log **diagnostic messages only** (no bearer tokens in logs). iOS uses **OSLog**; Android uses **`HiAirPush`** (`android.util.Log`).
- Android FCM registration token is still expected in private prefs `hiair_push` **only when** a future FCM integration writes it; until then push upload is skipped by design.

## Delta (2026-04-26 Phase 20)

- **Logout clears push local state:** iOS removes `UserDefaults` key `push.lastRegistrationStatus`; Android `SessionStore.clear()` also clears `hiair_push` prefs so cached FCM token does not survive logout.
