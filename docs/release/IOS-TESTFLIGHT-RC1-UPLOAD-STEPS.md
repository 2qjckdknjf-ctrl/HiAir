# iOS TestFlight RC1 Upload Steps

Status: BLOCKED_EXTERNAL until Apple Developer/App Store Connect signing and upload access are available.

## 1. Required Owner Inputs

- Apple Developer membership.
- App Store Connect access.
- Apple Team ID.
- Confirmed Bundle ID: `com.hiair.app`.
- Push Notifications enabled for the Bundle ID.
- Privacy Policy URL and Support URL approved by owner/legal.
- Internal tester Apple IDs.

## 2. Exact Xcode Archive Command

```bash
cd mobile/ios
xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Release -destination generic/platform=iOS -archivePath build/HiAir.xcarchive archive
```

Expected evidence:

- `mobile/ios/build/HiAir.xcarchive` exists.
- Xcode command exits successfully.

## 3. Exact Export Command

```bash
cd mobile/ios
xcodebuild -exportArchive -archivePath build/HiAir.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build
```

Expected evidence:

- `mobile/ios/build/HiAir.ipa` exists.
- export output reports success.

## 4. Create `ExportOptions.plist` From Template

```bash
cd mobile/ios
cp ExportOptions.plist.template ExportOptions.plist
```

Then replace:

```text
REPLACE_WITH_APPLE_TEAM_ID
```

with the real Apple Team ID locally. Do not commit private signing material.

## 5. Upload via Xcode Organizer

1. Open Xcode.
2. Open Window -> Organizer.
3. Select `HiAir.xcarchive`.
4. Click Distribute App.
5. Choose App Store Connect.
6. Choose Upload.
7. Follow signing prompts.
8. Wait until the build appears in App Store Connect.

## 6. Upload via Transporter

1. Open Transporter.
2. Sign in with App Store Connect account.
3. Add `mobile/ios/build/HiAir.ipa`.
4. Click Deliver.
5. Wait for upload and processing.

## 7. TestFlight Internal Group Setup

1. Open App Store Connect.
2. Open HiAir app.
3. Open TestFlight.
4. Create an internal testing group.
5. Add internal tester Apple IDs.
6. Attach the processed RC1 build.
7. Confirm testers receive access.

## 8. Beta Review Info

Fill in:

- beta contact name/email/phone;
- demo account if required;
- app purpose and health/environment context;
- test notes for onboarding, dashboard, risk, planner, symptoms, settings, push;
- privacy/support URLs.

External TestFlight testing may require Beta App Review. Internal testing still requires a processed build.

## 9. Evidence to Capture

- Apple Developer Bundle ID screenshot with Push Notifications enabled.
- Xcode archive success screenshot/log.
- IPA file path screenshot if exported.
- App Store Connect build processing screenshot.
- TestFlight internal group screenshot.
- Tester invitation/access screenshot.

## 10. Known Blockers

- `mobile/ios/build/HiAir.ipa` is missing locally.
- Apple Team ID and signing are not available in repo.
- App Store Connect app record and TestFlight group are external owner actions.
- Legal/store privacy URLs must be approved before broader beta review.
