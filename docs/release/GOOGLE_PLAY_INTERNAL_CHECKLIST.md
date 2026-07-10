# Google Play Internal Testing Checklist

**App:** HiAir  
**Application ID:** `com.hiair`  
**Version:** 0.1.0 (`versionCode` 2)  
**Updated:** 2026-07-10 (Mission #5)

## Pre-upload (engineering) — DONE

- [x] Release → `https://api.hiair.io` (`build.gradle.kts`)
- [x] Adaptive launcher icons + splash theme
- [x] `POST_NOTIFICATIONS` permission (Android 13+)
- [x] Health Connect permissions + Play compliance intents
- [x] Cleartext disabled in release manifest
- [x] Signed AAB: `mobile/android/app/build/outputs/bundle/release/app-release.aab`
- [x] `validate_signed_android_release.sh` — PASS (2026-07-10)
- [x] Upload SHA-1: `8A:60:8E:E1:00:D1:54:89:17:76:01:23:65:1C:6A:A9:74:BC:21:DE`
- [x] Upload scripts: `upload_play_internal.sh` + `upload_play_internal.py`

## Owner blockers (2026-07-10)

- [ ] **Create Play Console app** for package `com.hiair` (app not found in account `6120473136332405670`)
- [ ] Upload signed AAB to **Internal testing** (manual or service account JSON)
- [ ] Optional: `backend/.secrets/google-play-service-account.json` for automation
- [ ] Data safety, content rating, store listing (may block rollout)

## Build / validate (local)

```bash
export JAVA_HOME="/Users/alex/Library/Java/JavaVirtualMachines/jbr-17.0.14/Contents/Home"
bash scripts/release/validate_signed_android_release.sh
```

## Automated upload (after JSON)

```bash
# Place JSON at backend/.secrets/google-play-service-account.json
bash scripts/release/upload_play_internal.sh
```

Track: **internal** only.

## Manual Play Console upload

1. [App list](https://play.google.com/console/u/0/developers/6120473136332405670/app-list) → **Создать приложение** (if HiAir missing)
2. HiAir → **Testing → Internal testing → Create release**
3. Upload `app-release.aab`
4. Release notes: `docs/release/store/RELEASE_NOTES.md`
5. **Review release → Start rollout to Internal testing**

## Post-upload

- Verify upload certificate in **Setup → App integrity**
- Add internal testers + opt-in link
- Device QA: `docs/release/DEVICE_CERTIFICATION_CHECKLIST.md`

## Review credentials

- Email: `PLAY_REVIEW_TEST_EMAIL` in `backend/.env.local`
- Password: `PLAY_REVIEW_TEST_PASSWORD`
