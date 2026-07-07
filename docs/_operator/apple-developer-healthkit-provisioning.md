# Apple Developer — HealthKit Provisioning for TestFlight

**Symptom (legacy):** Archive failed with HealthKit provisioning profile error.

**Fix (automated):** Pass `-allowProvisioningUpdates` to `xcodebuild archive` and `exportArchive`. Xcode refreshes the App ID capability and profile. Verified **2026-07-07** — archive + TestFlight upload SUCCESS.

Manual portal fix (if `-allowProvisioningUpdates` unavailable):

1. Open [Apple Developer → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Select **App IDs** → `com.hiair.app`
3. Enable capability **HealthKit** → Save
4. Optional: enable **Sign in with Apple** if not already enabled
5. In Xcode (or Xcode Cloud): **Settings → Accounts → Download Manual Profiles**  
   Or delete old profiles and let automatic signing regenerate
6. Re-run archive:

```bash
bash mobile/ios/scripts/archive_and_upload_testflight.sh
```

## Verify after archive

```bash
bash scripts/ops/validate_ios_healthkit_ipa.sh mobile/ios/build/export/HiAir.ipa
```

Expected: HealthKit entitlement + privacy strings + PrivacyInfo.xcprivacy present.

## Xcode Cloud

After App ID capability is enabled, trigger **HiAir TestFlight** workflow on `main`. Xcode Cloud manages certificates if team access is granted in ASC.

See also: `docs/release/TESTFLIGHT_CHECKLIST.md`
