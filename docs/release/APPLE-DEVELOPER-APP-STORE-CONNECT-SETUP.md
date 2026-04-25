# Apple Developer / App Store Connect Setup

Status: BLOCKED_EXTERNAL until the owner provides Apple Developer membership, Team ID, signing, and App Store Connect access.

## 1. Apple Developer Access

1. Sign in at Apple Developer.
2. Confirm the account is enrolled in the Apple Developer Program.
3. Confirm the release owner has access to Certificates, Identifiers & Profiles.
4. Record the Apple Team ID in the private owner checklist. Do not commit it unless it is intentionally public for the team.

## 2. Bundle ID

1. Open Certificates, Identifiers & Profiles.
2. Create or confirm the HiAir Bundle ID used by the Xcode target.
3. Enable Push Notifications.
4. Confirm any required associated capabilities match the Xcode project.
5. Save evidence: Bundle ID screenshot and enabled capabilities screenshot.

## 3. App Store Connect App Record

1. Open App Store Connect.
2. Create a new app.
3. Select iOS platform.
4. Select the HiAir Bundle ID.
5. Set SKU to an owner-approved stable value, for example `hiair-ios`.
6. Set support URL and privacy URL placeholders only after owner/legal approval.
7. Save evidence: app record page screenshot.

## 4. Signing

1. Open `mobile/ios/HiAir.xcodeproj` in Xcode.
2. Select the HiAir target.
3. Set Team to the enrolled Apple Developer team.
4. Use automatic signing unless the owner requires manual profiles.
5. Verify the Release configuration builds for generic iOS device.

## 5. Archive

From repo root:

```bash
cd mobile/ios
xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Release -destination generic/platform=iOS -archivePath build/HiAir.xcarchive archive
```

Expected evidence:

- `mobile/ios/build/HiAir.xcarchive` exists.
- Xcode archive exits successfully.

## 6. Export IPA

1. Copy the template:

```bash
cd mobile/ios
cp ExportOptions.plist.template ExportOptions.plist
```

2. Replace `REPLACE_WITH_APPLE_TEAM_ID` with the real Team ID locally.
3. Export:

```bash
xcodebuild -exportArchive -archivePath build/HiAir.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build
```

Expected evidence:

- `mobile/ios/build/HiAir.ipa` exists.
- export output reports success.

## 7. Upload Build

Use one owner-approved path:

- Xcode Organizer: Distribute App -> App Store Connect -> Upload.
- Transporter: upload `mobile/ios/build/HiAir.ipa`.

Expected evidence:

- Build appears in App Store Connect.
- Processing completes without rejection.

## 8. TestFlight

1. Open the app in App Store Connect.
2. Open TestFlight.
3. Create an internal testing group.
4. Add internal tester Apple IDs.
5. Add beta review info and contact details.
6. Attach the uploaded build to the internal group.
7. For external testing, submit for Beta App Review only after legal/store metadata is approved.

Expected evidence:

- TestFlight build available to internal testers.
- Internal group screenshot.
- Beta review/contact info screenshot.
