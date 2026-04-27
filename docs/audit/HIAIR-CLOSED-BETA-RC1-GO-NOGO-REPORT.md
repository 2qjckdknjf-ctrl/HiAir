# HiAir Closed Beta RC1 Go/No-Go Report

## 1. Executive Summary

- RC label: `closed-beta-rc1`
- Current status: Closed Beta NEAR-GO; Public Launch NO-GO.
- Backend verdict: GO.
- iOS verdict: NEAR-GO.
- Android verdict: NEAR-GO.
- Push verdict: NEAR-GO for code, BLOCKED_EXTERNAL for live delivery.
- Store/legal verdict: LEGAL_SIGNOFF_REQUIRED.
- Ops verdict: BLOCKED_EXTERNAL.
- Closed Beta verdict: NEAR-GO.
- Public Launch verdict: NO-GO.

RC1 has the backend technical gate closed locally: PostgreSQL runtime, migrations/init, DB smoke, retention dry-run, API health, API preflight, and backend tests are GO. iOS simulator, iOS archive, iOS IPA export, and Android clean release/AAB builds are GO. The remaining blockers are owner/account/manual gates: TestFlight upload, Google Play Internal release, Firebase/APNs/FCM live push, legal/store approvals, ops ownership, and real-device QA.

## 2. Green Gates

| Gate | Evidence | Status |
| ---- | -------- | ------ |
| Backend local runtime | `pg_isready -h localhost -p 5432` accepts connections using manual `LC_ALL=C pg_ctl` runtime | GO |
| Backend tests | `30 passed` | GO |
| Backend smoke | `run_local_beta_smoke.sh` completed migrations, smoke, retention, env strict, historical risk | GO |
| API preflight | health returned `status=ok`; `beta_preflight.py` printed `Preflight passed.` | GO |
| iOS simulator | `xcodebuild ... iphonesimulator ... CODE_SIGNING_ALLOWED=NO` returned `** BUILD SUCCEEDED **` | GO |
| iOS archive | `mobile/ios/build/HiAir.xcarchive` exists | GO |
| iOS IPA | `mobile/ios/build/HiAir.ipa` exists after export | GO |
| Android release | clean Gradle build/lint returned `BUILD SUCCESSFUL` | GO |
| Android AAB | `mobile/android/app/build/outputs/bundle/release/app-release.aab` exists | GO |
| Push code | iOS/Android builds pass with push registration code included | GO |
| Final release manifest | `docs/release-artifacts-manifest.md` generated | GO |

## 3. Yellow Gates / NEAR-GO

| Gate | Why not GO | Required action |
| ---- | ---------- | --------------- |
| Android signing/upload | AAB exists, but Play App Signing/upload proof is external | owner uploads AAB to Play Internal and records signing evidence |
| Store metadata | packets exist, but portal values/URLs are owner/legal decisions | owner completes App Store/Play metadata using approved URLs |
| Real-device QA readiness | QA packet exists, but devices have not executed it | run iOS and Android physical-device QA packet |
| Closed Beta | technical local gates are GO, but external/manual gates remain | finish Apple, Google, Firebase, legal, ops, device QA |

## 4. Red Gates / NO-GO

| Gate | Why blocked | Required owner |
| ---- | ----------- | -------------- |
| TestFlight | build not uploaded to App Store Connect | Apple/release owner |
| Google Play Internal | internal release not created in Play Console | Google/release owner |
| Push live | APNs/FCM credentials and delivery evidence unavailable | Mobile/Ops owner |
| Legal | privacy/terms/privacy labels/Data Safety not signed off | Legal/Product owner |
| Ops | beta owner/on-call/support/WAF evidence not assigned | Project/Ops owner |
| Public Launch | live/legal/ops/store evidence incomplete | Project owner |

## 5. Backend RC1 Evidence

| Check | Result | Status |
| ----- | ------ | ------ |
| PostgreSQL runtime | accepting connections on `localhost:5432` | GO |
| pytest | `30 passed` | GO |
| migrations/init | `Database schema initialized (5 migrations).` | GO |
| DB smoke | `DB smoke flow passed.` | GO |
| retention dry-run | `Retention cleanup completed.` | GO |
| env strict | `Environment security check passed.` | GO |
| historical validation | `passed: True`, `cases: 4/4` | GO |
| API health | `{"status":"ok","service":"hiair-backend",...}` | GO |
| API preflight | all checks `[OK]`; `Preflight passed.` | GO |

## 6. iOS RC1 Evidence

| Check | Result | Status |
| ----- | ------ | ------ |
| Bundle ID | `com.hiair.app` | GO |
| Marketing/build version | `0.1.0` / `1` | GO |
| simulator build | `** BUILD SUCCEEDED **` | GO |
| archive | `mobile/ios/build/HiAir.xcarchive` | GO |
| export options template | `mobile/ios/ExportOptions.plist.template` | GO |
| IPA | `mobile/ios/build/HiAir.ipa` exists | GO |
| TestFlight | no App Store Connect upload evidence | BLOCKED_EXTERNAL |

## 7. Android RC1 Evidence

| Check | Result | Status |
| ----- | ------ | ------ |
| applicationId | `com.hiair` | GO |
| versionName/versionCode | `0.1.0` / `1` | GO |
| clean build/lint | `BUILD SUCCESSFUL` | GO |
| debug APK | `mobile/android/app/build/outputs/apk/debug/app-debug.apk` | GO |
| release APK | `mobile/android/app/build/outputs/apk/release/app-release-unsigned.apk` | GO |
| release AAB | `mobile/android/app/build/outputs/bundle/release/app-release.aab` | GO |
| Play Internal | no Play Console upload evidence | BLOCKED_EXTERNAL |

## 8. Push RC1 Evidence

| Check | Result | Status |
| ----- | ------ | ------ |
| iOS push registration code | builds in simulator | GO |
| Android notification/token path | builds in clean Android release | GO |
| APNs credential setup | owner guide exists, credentials not provided | BLOCKED_EXTERNAL |
| FCM credential setup | owner guide exists, Firebase config not provided | BLOCKED_EXTERNAL |
| live device delivery | no APNs/FCM physical-device proof | BLOCKED_EXTERNAL |

## 9. Store / Legal / Ops Evidence

| Area | Result | Status |
| ---- | ------ | ------ |
| Apple setup guide | `docs/release/APPLE-DEVELOPER-APP-STORE-CONNECT-SETUP.md` | GO |
| TestFlight RC1 steps | `docs/release/IOS-TESTFLIGHT-RC1-UPLOAD-STEPS.md` | GO |
| Google setup guide | `docs/release/GOOGLE-PLAY-CONSOLE-INTERNAL-TEST-SETUP.md` | GO |
| Android RC1 upload steps | `docs/release/ANDROID-GOOGLE-PLAY-RC1-UPLOAD-STEPS.md` | GO |
| Firebase/APNs/FCM guide | `docs/release/FIREBASE-APNS-FCM-SETUP.md` | GO |
| legal/store packet | docs exist; legal approval absent | LEGAL_SIGNOFF_REQUIRED |
| ops runbook | docs exist; owner/on-call/WAF evidence absent | BLOCKED_EXTERNAL |
| real-device QA | packet exists; execution absent | NOT_VERIFIED |

## 10. Final Verdict Table

| Target | Verdict | Why |
| ------ | ------- | --- |
| Backend local runtime | GO | local PostgreSQL accepts connections |
| Backend tests | GO | `30 passed` |
| Backend smoke | GO | smoke helper passed DB flow and retention |
| API preflight | GO | API health and preflight passed |
| iOS simulator | GO | simulator build succeeded |
| iOS archive | GO | `.xcarchive` exists |
| iOS IPA | GO | IPA exported at `mobile/ios/build/HiAir.ipa` |
| TestFlight | BLOCKED_EXTERNAL | requires App Store Connect upload and tester group |
| Android release | GO | clean release build/lint succeeded |
| Android AAB | GO | AAB exists |
| Google Play Internal | BLOCKED_EXTERNAL | requires Play Console internal release |
| Push code | GO | mobile builds include push paths |
| Push live | BLOCKED_EXTERNAL | requires APNs/FCM credentials and physical devices |
| Store metadata | NEAR-GO | packets exist, portal fields/URLs pending |
| Legal | LEGAL_SIGNOFF_REQUIRED | final legal approval missing |
| Ops | BLOCKED_EXTERNAL | beta/on-call/support/WAF evidence missing |
| Real-device QA | NOT_VERIFIED | physical devices have not executed QA packet |
| Closed Beta | NEAR-GO | technical gates are GO; external/manual gates remain |
| Public Launch | NO-GO | legal, store, ops, live push, and production evidence incomplete |

## 11. Exact Next Actions for Aleksandr

1. Открой `docs/release/ALEKSANDR-CLOSED-BETA-ACTION-CHECKLIST-RU.md` и используй его как основной чеклист.
2. Подтверди backend: запусти `pg_isready -h localhost -p 5432`, затем `cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh`.
3. Открой Apple Developer, проверь membership, создай/подтверди Bundle ID `com.hiair.app` и включи Push Notifications.
4. Открой App Store Connect, создай app record HiAir, заполни SKU, support URL, privacy URL и beta contact.
5. Загрузи iOS build из `mobile/ios/build/HiAir.ipa` в TestFlight через Xcode Organizer или Transporter.
6. В App Store Connect создай internal testing group и добавь тестеров.
7. Открой Google Play Console, создай приложение с package `com.hiair`, выбери Play App Signing и загрузи `mobile/android/app/build/outputs/bundle/release/app-release.aab`.
8. Заполни Play Data Safety, content rating и privacy policy URL только после legal/product approval.
9. Открой Firebase, создай проект, добавь Android `com.hiair` и iOS `com.hiair.app`, настрой APNs/FCM без коммита секретов.
10. Назначь beta owner, on-call owner, support channel, WAF/rate limiting owner и выполни `docs/qa/HIAIR-RC1-REAL-DEVICE-QA-PACKET.md` на реальных устройствах.
