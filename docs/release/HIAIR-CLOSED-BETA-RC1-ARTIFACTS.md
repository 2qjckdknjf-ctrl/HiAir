# HiAir Closed Beta RC1 Artifacts

RC label: `closed-beta-rc1`

## 1. Backend Evidence

| Artifact/Evidence | Path or command | Status |
| ----------------- | --------------- | ------ |
| PostgreSQL local runtime | `LC_ALL=C pg_ctl -D ~/.hiair/postgres-data -l ~/.hiair/postgres.log start` | GO |
| PostgreSQL readiness | `pg_isready -h localhost -p 5432` | GO |
| pytest | `cd backend && ../.venv/bin/python -m pytest -q` -> `30 passed` | GO |
| smoke | `cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh` | GO |
| migrations/init | smoke helper reported `Database schema initialized (5 migrations).` | GO |
| retention dry-run | smoke helper reported retention cleanup completed | GO |
| API health | `curl http://127.0.0.1:8000/api/health` returned `status=ok` | GO |
| API preflight | `scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"` -> `Preflight passed.` | GO |
| env safety | `.env.local` uses local-only placeholders and stub providers; production secrets not used | GO |

## 2. iOS Evidence

| Artifact/Evidence | Path or command | Status |
| ----------------- | --------------- | ------ |
| simulator build | `cd mobile/ios && xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO` | GO |
| archive | `mobile/ios/build/HiAir.xcarchive` | GO |
| IPA | `mobile/ios/build/HiAir.ipa` | BLOCKED_EXTERNAL |
| export options template | `mobile/ios/ExportOptions.plist.template` | GO |
| export options example | `mobile/ios/ExportOptions.plist.example` | GO |
| TestFlight packet | `docs/release/TESTFLIGHT-BETA-LAUNCH-PACKET.md` | GO |
| Apple setup guide | `docs/release/APPLE-DEVELOPER-APP-STORE-CONNECT-SETUP.md` | GO |

## 3. Android Evidence

| Artifact/Evidence | Path | Status |
| ----------------- | ---- | ------ |
| debug APK | `mobile/android/app/build/outputs/apk/debug/app-debug.apk` | GO |
| release APK | `mobile/android/app/build/outputs/apk/release/app-release-unsigned.apk` | GO |
| release AAB | `mobile/android/app/build/outputs/bundle/release/app-release.aab` | GO |
| lint report | `mobile/android/app/build/reports/lint-results-debug.html` | GO |
| clean build/lint | `cd mobile/android && ./gradlew clean assembleDebug assembleRelease bundleRelease lint` -> `BUILD SUCCESSFUL` | GO |
| Play Internal packet | `docs/release/GOOGLE-PLAY-INTERNAL-BETA-LAUNCH-PACKET.md` | GO |
| Google setup guide | `docs/release/GOOGLE-PLAY-CONSOLE-INTERNAL-TEST-SETUP.md` | GO |

## 4. Docs / Owner Packets

- `docs/release/HIAIR-CLOSED-BETA-OWNER-EXECUTION-PACKET.md`
- `docs/release/APPLE-DEVELOPER-APP-STORE-CONNECT-SETUP.md`
- `docs/release/IOS-TESTFLIGHT-RC1-UPLOAD-STEPS.md`
- `docs/release/GOOGLE-PLAY-CONSOLE-INTERNAL-TEST-SETUP.md`
- `docs/release/ANDROID-GOOGLE-PLAY-RC1-UPLOAD-STEPS.md`
- `docs/release/FIREBASE-APNS-FCM-SETUP.md`
- `docs/release/STORE-LEGAL-METADATA-LAUNCH-PACKET.md`
- `docs/ops/CLOSED-BETA-OPS-RUNBOOK.md`
- `docs/qa/IOS-REAL-DEVICE-QA-SCRIPT.md`
- `docs/qa/ANDROID-REAL-DEVICE-QA-SCRIPT.md`
- `docs/qa/HIAIR-RC1-REAL-DEVICE-QA-PACKET.md`

## 5. Missing Artifacts

| Artifact | Why missing | Required owner action |
| -------- | ----------- | --------------------- |
| iOS IPA | Requires Apple Team ID/signing and export with owner credentials | Create `ExportOptions.plist` from template, archive/export with Apple team, upload to App Store Connect |
| signed Android upload proof | Local artifact exists, but Play Console signing/upload has not happened | Decide Play App Signing/upload key path, upload AAB to internal testing |
| live push evidence | APNs/FCM credentials and physical devices are external | Configure Firebase/APNs/FCM and run device push QA |
| TestFlight build number | Build has not been uploaded to App Store Connect | Upload IPA/archive and capture TestFlight build evidence |
| Play Internal release number | Internal release has not been created in Play Console | Create internal testing release and capture release evidence |
