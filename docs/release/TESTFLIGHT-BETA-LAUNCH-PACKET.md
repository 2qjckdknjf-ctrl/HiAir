# TestFlight Beta Launch Packet

Status: BLOCKED_EXTERNAL

## Required Apple Inputs

- Apple Developer Team ID: BLOCKED_EXTERNAL
- Bundle ID: `com.hiair.app`
- Signing certificates: BLOCKED_EXTERNAL
- Provisioning profile: BLOCKED_EXTERNAL
- App Store Connect app record: BLOCKED_EXTERNAL
- TestFlight internal testing group: BLOCKED_EXTERNAL
- Support URL: BLOCKED_EXTERNAL
- Privacy policy URL: LEGAL_SIGNOFF_REQUIRED
- Beta app review contact: BLOCKED_EXTERNAL
- Export compliance answer: READY_FOR_OWNER

## Local Commands

```bash
cd mobile/ios
xcodebuild -list -project HiAir.xcodeproj
xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Release -sdk iphoneos archive -archivePath build/HiAir.xcarchive
cp ExportOptions.plist.template ExportOptions.plist
# Replace REPLACE_WITH_APPLE_TEAM_ID locally. Do not commit real team IDs.
xcodebuild -exportArchive -archivePath build/HiAir.xcarchive -exportPath build/export -exportOptionsPlist ExportOptions.plist
```

## Upload Checklist

- [ ] App Store Connect app exists.
- [ ] Bundle ID matches `com.hiair.app`.
- [ ] Build number is incremented if re-uploading.
- [ ] Privacy URL and support URL are final.
- [ ] Internal tester group exists.
- [ ] Beta notes include wellness/non-medical limitation.
- [ ] Export compliance answer reviewed.

## Current Local Evidence

- iOS simulator build: GO.
- Signed archive/IPA export: BLOCKED_EXTERNAL.
