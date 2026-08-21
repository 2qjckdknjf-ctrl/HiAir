# TestFlight Upload Checklist

**App:** HiAir (`com.hiair.app`)  
**Version target on redesign ship line:** 1.0 (build 188)  
**Last proven uploaded Apple build:** 181 (VALID on 2026-08-11)  
**Important:** build 188 is code-aligned in repo but must still be archived/uploaded from macOS/Xcode.
**Team:** `43A4KW5BKB`

## Pre-upload (engineering)

- [x] Release → `https://api.hiair.io` (`project.yml` Release config)
- [x] App icons + LaunchScreen present
- [x] PrivacyInfo.xcprivacy (Health, email, coarse location declarations)
- [x] HealthKit entitlements + usage strings in Info.plist
- [x] Sign in with Apple entitlement
- [x] ExportOptions.plist (`app-store`, team automatic)
- [x] Upload script: `mobile/ios/scripts/upload_ipa_testflight_api.sh`
- [x] Archive script: `mobile/ios/scripts/archive_and_upload_testflight.sh`
- [ ] **Owner:** App ID `com.hiair.app` has **HealthKit** capability in Apple Developer Portal
- [ ] **Owner:** Provisioning profile regenerated with HealthKit (fixes archive error)

## Upload paths

### A) Xcode Cloud (recommended)

See `docs/release/XCODE_CLOUD_SETUP.md` — push to `main`, workflow **HiAir TestFlight**.

### B) Local (Xcode 26+)

```bash
bash mobile/ios/scripts/archive_and_upload_testflight.sh
export APPLE_ISSUER_ID="$(cat backend/.secrets/apple_issuer_id)"
bash mobile/ios/scripts/upload_ipa_testflight_api.sh
```

### C) Xcode Organizer

Archive → Distribute App → App Store Connect.

## Post-upload validation

```bash
bash scripts/ops/validate_ios_healthkit_ipa.sh mobile/ios/build/export/HiAir.ipa
```

- [ ] TestFlight processing complete (ASC)
- [ ] Internal testers invited
- [ ] Login (email + Sign in with Apple)
- [ ] Dashboard shows live/cached/sample source label
- [ ] Privacy export/delete
- [ ] HealthKit consent flow

## Release notes

Use `docs/release/store/RELEASE_NOTES.md` and `docs/release/store/REVIEWER_NOTES.md`.

## Known upload blocker (2026-07-07)

~~Local archive fails until HealthKit is enabled on App ID~~ **RESOLVED** — use `-allowProvisioningUpdates` on archive/export (see `archive_and_upload_testflight.sh`).

Current operator goal: upload **188** and verify processing before claiming TestFlight parity with Android 188.
