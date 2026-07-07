# Operator Certification Mission #2 — Status

**Updated:** 2026-07-07  
**Commit:** pending

## Results

| Goal | Status | Evidence |
|------|--------|----------|
| First TestFlight build | **SUCCESS** | ASC build **65** `processing=VALID`, upload UUID `433b9bdc-3ca2-4f84-9365-888643d471b9` |
| Play Internal release | **BLOCKED** | No `keystore.properties` / signed AAB |

## TestFlight (completed)

1. Archive with `-allowProvisioningUpdates` — HealthKit provisioning auto-fixed
2. HealthKit validation — PASS (`validate_ios_healthkit_ipa.sh`)
3. Export IPA — PASS (`ExportOptions.plist` → `app-store-connect`)
4. Upload — PASS (`upload_ipa_testflight_api.sh`)
5. ASC app `com.hiair.app` id=`6773610034`

**Build:** 0.1.0 (13) → ASC build number 65  
**API:** Release → `https://api.hiair.io`

## Google Play (owner action required)

Unsigned AAB ready at `mobile/android/app/build/outputs/bundle/release/app-release.aab` (versionCode 2).

Owner must:
1. Create `mobile/android/keystore.properties` from example
2. Rebuild signed AAB
3. Upload via Play Console or `scripts/release/upload_play_internal.sh` (needs service account JSON)

## Commands for next upload

```bash
# iOS
bash mobile/ios/scripts/archive_and_upload_testflight.sh
export APPLE_ISSUER_ID="$(cat backend/.secrets/apple_issuer_id)"
bash mobile/ios/scripts/upload_ipa_testflight_api.sh

# Android (after keystore)
bash scripts/release/build_android_play_internal.sh
bash scripts/release/upload_play_internal.sh
```
