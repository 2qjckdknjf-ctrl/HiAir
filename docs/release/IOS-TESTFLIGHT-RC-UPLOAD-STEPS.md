# iOS TestFlight RC upload steps

This document is the **generic RC** companion to `docs/release/IOS-TESTFLIGHT-RC1-UPLOAD-STEPS.md` (same procedure, any RC label).

## Status

**BLOCKED_EXTERNAL** until Apple Developer Program, App Store Connect access, and signing certificates/profiles are available.

## Do not commit

- Apple Distribution private keys, `.p12`, provisioning profiles with embedded secrets, or real `ExportOptions.plist` with team secrets.
- APNs auth key `.p8`.

## Steps (summary)

1. Confirm Bundle ID `com.hiair.app` and Push Notifications capability in Apple Developer.
2. Archive:

```bash
cd mobile/ios
xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Release -destination generic/platform=iOS -archivePath build/HiAir.xcarchive archive
```

3. Create `ExportOptions.plist` from `ExportOptions.plist.template` **locally only**; substitute Team ID.
4. Export IPA:

```bash
xcodebuild -exportArchive -archivePath build/HiAir.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build
```

5. Upload via Xcode Organizer or Apple Transporter.
6. Attach evidence: successful processing in App Store Connect, internal group, tester access.

## Full detail

See **`docs/release/IOS-TESTFLIGHT-RC1-UPLOAD-STEPS.md`** and **`docs/release/TESTFLIGHT-BETA-LAUNCH-PACKET.md`**.
