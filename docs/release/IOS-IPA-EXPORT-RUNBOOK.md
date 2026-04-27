# iOS IPA Export Runbook

Status: BLOCKED_EXTERNAL for signed IPA export.

## Verified locally

- `xcodebuild -list -project HiAir.xcodeproj`
- iOS simulator build with `CODE_SIGNING_ALLOWED=NO`

## Archive command

Requires Apple Developer signing setup:

```bash
cd mobile/ios
xcodebuild \
  -project HiAir.xcodeproj \
  -scheme HiAir \
  -configuration Release \
  -destination generic/platform=iOS \
  -archivePath build/HiAir.xcarchive \
  archive
```

## IPA export command

Copy and edit the template first:

```bash
cp ExportOptions.plist.example ExportOptions.plist
# Replace REPLACE_WITH_APPLE_TEAM_ID and confirm App Store Connect method.
```

Then export:

```bash
xcodebuild \
  -exportArchive \
  -archivePath build/HiAir.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

Expected IPA path:

```text
mobile/ios/build/export/HiAir.ipa
```

## App Store Connect upload checklist

- [ ] Apple Developer account access. Status: BLOCKED_EXTERNAL.
- [ ] App Store Connect app record for `com.hiair.app`. Status: BLOCKED_EXTERNAL.
- [ ] Signing team and provisioning profile available. Status: BLOCKED_EXTERNAL.
- [ ] Final privacy URL and support URL. Status: LEGAL_SIGNOFF_REQUIRED / BLOCKED_EXTERNAL.
- [ ] Release notes and screenshot set attached.
- [ ] TestFlight internal group configured.

## Limitations

Simulator builds do not produce store-uploadable IPAs. Unsigned archive/export cannot close TestFlight readiness.
