# HiAir Mobile Beta Build Commands

This document is a command-oriented companion for closed beta releases.

## iOS (TestFlight)

From `mobile/ios`:

```bash
xcodebuild -project "HiAir.xcodeproj" -scheme "HiAir" -configuration Debug -destination "generic/platform=iOS Simulator" build
xcodebuild -project "HiAir.xcodeproj" -scheme "HiAir" -configuration Release -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO archive -archivePath "build/HiAir.xcarchive"
```

Open project in Xcode and configure:
- signing team
- bundle id
- version and build number

Archive and upload:

1. Product -> Archive
2. Distribute App -> App Store Connect -> Upload
3. Assign build to TestFlight Internal Testing group

Release notes source:
- `docs/release-notes-template.md`

## Android (Google Play Internal Test)

From `mobile/android`:

```bash
./gradlew :app:assembleDebug --no-daemon
./gradlew :app:bundleRelease --no-daemon
```

Then:
1. Set `versionCode` and `versionName` if releasing new candidate.
2. Upload AAB to Google Play Console -> Internal testing.
3. Assign testers and publish to internal track.

Release notes source:
- `docs/release-notes-template.md`

## Artifact manifest (recommended before upload)

From repository root:

```bash
python3 mobile/scripts/generate_release_manifest.py
```

Strict check (requires Android AAB + iOS xcarchive):

```bash
python3 mobile/scripts/generate_release_manifest.py --strict
```

## Naming convention

- iOS build label: `hiair-ios-beta-<YYYYMMDD>-b<build>`
- Android build label: `hiair-android-beta-<YYYYMMDD>-b<build>`

## Mandatory checks before upload

Run from `backend/`:

```bash
.venv/bin/python scripts/init_db.py
.venv/bin/python scripts/smoke_db_flow.py
.venv/bin/python scripts/validate_risk_historical.py
.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000
```
