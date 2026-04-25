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
