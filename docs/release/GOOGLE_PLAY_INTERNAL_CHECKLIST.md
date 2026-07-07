# Google Play Internal Testing Checklist

**App:** HiAir  
**Application ID:** `com.hiair`  
**Version:** 0.1.0 (`versionCode` 2)

## Pre-upload (engineering)

- [x] Release → `https://api.hiair.io` (`build.gradle.kts`)
- [x] Adaptive launcher icons + splash theme
- [x] `POST_NOTIFICATIONS` permission (Android 13+)
- [x] Health Connect permissions declared
- [x] Cleartext disabled in release manifest
- [x] AAB build script: `scripts/release/build_android_play_internal.sh`
- [x] Signing scaffold: `keystore.properties.example`
- [ ] **Owner:** Create release keystore + `mobile/android/keystore.properties`
- [ ] **Owner:** Play Console app created for `com.hiair`

## Build signed AAB

```bash
cd mobile/android
cp keystore.properties.example keystore.properties
# edit storeFile path and passwords
bash ../../scripts/release/build_android_play_internal.sh
```

Output: `mobile/android/app/build/outputs/bundle/release/app-release.aab`

## Validate before upload

```bash
bash scripts/release/validate_store_release_builds.sh android
```

## Play Console steps (owner)

1. Play Console → HiAir → **Testing → Internal testing**
2. Create release → Upload AAB
3. Add release notes from `docs/release/store/RELEASE_NOTES.md`
4. Complete **Data safety** using `docs/release/store/DATA_SAFETY.md`
5. Content rating questionnaire
6. Add internal testers (email list)

## Post-upload device checks

See `docs/release/DEVICE_CERTIFICATION_CHECKLIST.md`.

## Review credentials

- Email: value from `APP_REVIEW_TEST_EMAIL` in `backend/.env.local`
- Password: `APP_REVIEW_TEST_PASSWORD` (store in Play App access section)

## Known upload blocker (2026-07-07)

Unsigned AAB builds successfully but **Play Console requires signed AAB**. Owner must provide keystore.
