# HiAir Beta Cycle 002 Report

Date: 2026-04-07
Owner: engineering
Scope: end-to-end beta candidate build validation (backend + iOS + Android)

## Backend checks

From `backend/`:

```bash
.venv/bin/python scripts/init_db.py
.venv/bin/python scripts/smoke_db_flow.py
.venv/bin/python scripts/validate_risk_historical.py
.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000
```

Result:
- `init_db.py`: passed
- `smoke_db_flow.py`: passed
- `validate_risk_historical.py`: passed (`4/4`)
- `beta_preflight.py`: passed

## iOS build checks

From `mobile/ios`:

```bash
xcodebuild -project "HiAir.xcodeproj" -scheme "HiAir" -configuration Debug -destination "generic/platform=iOS Simulator" build
xcodebuild -project "HiAir.xcodeproj" -scheme "HiAir" -configuration Release -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO archive -archivePath "build/HiAir.xcarchive"
```

Result:
- Simulator build: passed
- Unsigned release archive: passed
- Artifact: `mobile/ios/build/HiAir.xcarchive`

## Android build checks

From `mobile/android`:

```bash
./gradlew :app:assembleDebug --no-daemon
./gradlew :app:bundleRelease --no-daemon
```

Result:
- Debug APK build: passed
- Release AAB build: passed
- Artifacts:
  - `mobile/android/app/build/outputs/apk/debug/app-debug.apk`
  - `mobile/android/app/build/outputs/bundle/release/app-release.aab`

## Infrastructure updates in this cycle

- Added Gradle Wrapper for Android project:
  - `mobile/android/gradlew`
  - `mobile/android/gradlew.bat`
  - `mobile/android/gradle/wrapper/*`
- Added local Android SDK mapping file for local build:
  - `mobile/android/local.properties`

## Remaining blockers for store upload

- TestFlight upload requires Apple Developer/App Store Connect access and signing profile.
- Google Play Internal upload requires Play Console access and release publishing permissions.

## Go / No-Go

- Decision: `GO` for closed beta upload step.
- Technical readiness: backend and mobile build pipeline validated locally.
- Operational dependency: account-level access to Apple/Google consoles.
