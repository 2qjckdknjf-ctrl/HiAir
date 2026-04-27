# HiAir Closed Beta Owner Execution Packet

## 1. Current Status

| Area | Verdict | Evidence |
| ---- | ------- | -------- |
| Backend tests | GO | `cd backend && ../.venv/bin/python -m pytest -q` previously reported `30 passed`; final rerun required before upload |
| Backend DB smoke | BLOCKED_BY_ENV | Local Postgres is not accepting connections on `localhost:5432` |
| API preflight | BLOCKED_BY_ENV | API server is not running because DB runtime is unavailable |
| iOS archive | GO | `mobile/ios/build/HiAir.xcarchive` found by release manifest |
| iOS IPA export | BLOCKED_EXTERNAL | Requires Apple Developer team/signing and App Store Connect upload path |
| Android AAB | GO | `mobile/android/app/build/outputs/bundle/release/app-release.aab` found |
| Google Play Internal | BLOCKED_EXTERNAL | Requires Play Console access, signing decision, tester group, Data Safety |
| Push live E2E | BLOCKED_EXTERNAL | Requires APNs/Firebase credentials and physical devices |
| Legal/store | LEGAL_SIGNOFF_REQUIRED | Privacy, Terms, App Store privacy labels, and Google Data Safety need approval |
| Ops | BLOCKED_EXTERNAL | Beta owner, on-call owner, support channel, WAF/rate limiting evidence not assigned |

## 2. What Is Already Green

- Backend tests have passed locally in Phase 3.
- iOS simulator build passed in Phase 3.
- Android debug/release/lint passed in Phase 3.
- Android `bundleRelease` generated an AAB.
- Release docs and QA scripts are prepared.
- Local-only env example, Docker Compose Postgres config, and smoke helper are prepared.

## 3. What Owner Must Do Now

### P0 - Backend Runtime

1. From repo root, prepare local env:

```bash
cp backend/.env.local.example backend/.env.local
```

2. Start Postgres with one safe local option.

Homebrew:

```bash
brew install postgresql@16
brew services start postgresql@16
createuser hiair || true
createdb -O hiair hiair || true
psql -d hiair -c "ALTER USER hiair WITH PASSWORD 'hiair';"
pg_isready -h localhost -p 5432
```

Docker:

```bash
docker compose -f backend/docker-compose.local.yml up -d postgres
pg_isready -h localhost -p 5432
```

3. Run the backend smoke:

```bash
cd backend
PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh
```

4. Start API and run preflight:

```bash
cd backend
set -a
source .env.local
set +a
../.venv/bin/python scripts/init_db.py
../.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

In another terminal:

```bash
cd backend
set -a
source .env.local
set +a
curl http://127.0.0.1:8000/api/health
../.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"
```

### P0 - Apple / TestFlight

1. Confirm Apple Developer membership and App Store Connect access.
2. Create or confirm Bundle ID for HiAir and enable Push Notifications.
3. Create the App Store Connect app record with Bundle ID, SKU, support URL, and privacy URL placeholders approved by owner/legal.
4. In Xcode, select the Apple Team and valid signing profiles.
5. Archive:

```bash
cd mobile/ios
xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Release -destination generic/platform=iOS -archivePath build/HiAir.xcarchive archive
```

6. Copy `mobile/ios/ExportOptions.plist.template` to `mobile/ios/ExportOptions.plist`, replace the Team ID placeholder, and export:

```bash
xcodebuild -exportArchive -archivePath build/HiAir.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build
```

7. Upload the IPA with Xcode Organizer or Transporter and create an internal TestFlight group.

### P0 - Google Play Internal

1. Confirm Play Console access and package name.
2. Decide Play App Signing and upload-key ownership.
3. Use the existing AAB:

```text
mobile/android/app/build/outputs/bundle/release/app-release.aab
```

4. Create an Internal testing release, upload the AAB, add tester emails, complete Data Safety/content rating/privacy policy fields, then roll out to internal testing.

### P1 - Push

1. Enable APNs for the Apple Bundle ID.
2. Create Firebase project, add Android package and iOS bundle ID.
3. Download `google-services.json` only to local/dev machines or secret-managed CI; do not commit it.
4. Upload APNs key/cert to Firebase and configure backend notification env variables in the deployment secret manager.
5. Run physical-device QA for APNs token upload, FCM token upload, and backend delivery attempts.

### P1 - Legal / Store

1. Approve Privacy Policy and Terms URLs.
2. Confirm GDPR controller/contact and DSAR channel.
3. Complete App Store privacy labels.
4. Complete Google Play Data Safety.
5. Attach final legal evidence to the release checklist.

### P1 - Ops

1. Assign beta owner and on-call owner.
2. Create support channel and response SLA.
3. Configure WAF/rate limiting before internet beta exposure.
4. Document rollback steps and release owner.
5. Run daily beta review during the first beta window.

## 4. Exact Files to Open

- `docs/backend/LOCAL-STAGING-BETA-SMOKE.md`
- `docs/backend/API-SERVER-LOCAL-RUNBOOK.md`
- `docs/release/TESTFLIGHT-BETA-LAUNCH-PACKET.md`
- `docs/release/GOOGLE-PLAY-INTERNAL-BETA-LAUNCH-PACKET.md`
- `docs/notifications/PUSH-E2E-LAUNCH-PACKET.md`
- `docs/release/STORE-LEGAL-METADATA-LAUNCH-PACKET.md`
- `docs/ops/CLOSED-BETA-OPS-RUNBOOK.md`
- `docs/release/APPLE-DEVELOPER-APP-STORE-CONNECT-SETUP.md`
- `docs/release/GOOGLE-PLAY-CONSOLE-INTERNAL-TEST-SETUP.md`
- `docs/release/FIREBASE-APNS-FCM-SETUP.md`

## 5. Exact Commands to Run

Backend:

```bash
cp backend/.env.local.example backend/.env.local
brew services start postgresql@16 || true
docker compose -f backend/docker-compose.local.yml up -d postgres || true
cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh
cd backend && set -a && source .env.local && set +a && ../.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
cd backend && set -a && source .env.local && set +a && ../.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"
```

iOS:

```bash
cd mobile/ios
xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Release -destination generic/platform=iOS -archivePath build/HiAir.xcarchive archive
xcodebuild -exportArchive -archivePath build/HiAir.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build
```

Android:

```bash
cd mobile/android
./gradlew assembleDebug assembleRelease bundleRelease lint
```

Release manifest:

```bash
python3 mobile/scripts/generate_release_manifest.py --strict
```

## 6. Evidence to Collect

| Area | Evidence |
| ---- | -------- |
| Backend runtime | `run_local_beta_smoke.sh` output with migrations, smoke, retention, historical risk all DONE |
| API preflight | `beta_preflight.py` output with every endpoint `[OK]` |
| TestFlight | Build visible in App Store Connect/TestFlight with internal group attached |
| Google Play | Internal testing release visible with tester list and AAB uploaded |
| Push | APNs and FCM token upload logs plus delivered notification proof |
| Legal | Signed privacy/terms/Data Safety/App Store privacy labels |
| Ops | Named owners, support channel, rollback plan, WAF/rate limiting screenshot or config |

## 7. Final Closed Beta Go/No-Go Checklist

| Gate | Required evidence | Status |
| ---- | ----------------- | ------ |
| Backend DB smoke | Postgres initialized and smoke exits 0 | BLOCKED_BY_ENV |
| API preflight | Running API returns full preflight success | BLOCKED_BY_ENV |
| iOS IPA export | IPA exported with Apple signing | BLOCKED_EXTERNAL |
| TestFlight internal | Build uploaded and assigned to internal testers | BLOCKED_EXTERNAL |
| Android AAB | AAB generated | GO |
| Google Play Internal | Internal testing release created | BLOCKED_EXTERNAL |
| Push live E2E | APNs/FCM delivery proven on devices | BLOCKED_EXTERNAL |
| Legal/store | Legal signoff and store forms complete | LEGAL_SIGNOFF_REQUIRED |
| Ops | Beta/on-call/support/WAF evidence assigned | BLOCKED_EXTERNAL |
| Closed Beta | All P0 gates green and P1 launch controls assigned | NEAR-GO |
