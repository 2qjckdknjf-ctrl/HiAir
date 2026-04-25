# Phase 6 Closed Beta RC1 Freeze Register

Snapshot date: 2026-04-25

RC label: `closed-beta-rc1`

| ID | RC Gate | Required evidence | Current evidence | Status |
| -- | ------- | ----------------- | ---------------- | ------ |
| RC1-001 | backend tests | `pytest` exits 0 | `cd backend && ../.venv/bin/python -m pytest -q` returned `30 passed` | GO |
| RC1-002 | backend smoke | local DB smoke exits 0 | `run_local_beta_smoke.sh` completed Postgres, migrations, smoke, retention, env strict, historical risk | GO |
| RC1-003 | API preflight | running API returns full preflight success | `/api/health` returned `status=ok`; `beta_preflight.py` printed `Preflight passed.` | GO |
| RC1-004 | iOS simulator build | simulator build succeeds without signing | `xcodebuild ... -sdk iphonesimulator ... CODE_SIGNING_ALLOWED=NO` returned `** BUILD SUCCEEDED **` | GO |
| RC1-005 | iOS archive exists | `.xcarchive` exists | `mobile/ios/build/HiAir.xcarchive` found by release manifest and artifact search | GO |
| RC1-006 | iOS IPA export readiness | exported `.ipa` exists | `mobile/ios/build/HiAir.ipa` exported successfully with local Apple signing | GO |
| RC1-007 | Android release build | clean release build succeeds | `./gradlew clean assembleDebug assembleRelease bundleRelease lint` returned `BUILD SUCCESSFUL` | GO |
| RC1-008 | Android bundleRelease/AAB exists | AAB exists | `mobile/android/app/build/outputs/bundle/release/app-release.aab` exists | GO |
| RC1-009 | Android signing readiness | upload signing/Play signing decision | local release APK is unsigned; Play Console signing decision not provided | BLOCKED_EXTERNAL |
| RC1-010 | push code readiness | push registration code compiles | iOS simulator and Android clean build passed with push registration code included | GO |
| RC1-011 | push live readiness | APNs/FCM credentials and real-device delivery evidence | Firebase/APNs/FCM setup guide exists; live delivery not verified | BLOCKED_EXTERNAL |
| RC1-012 | store metadata readiness | owner/store metadata packet exists | store/legal packet and setup guides exist; final portal entries still external | NEAR-GO |
| RC1-013 | legal readiness | privacy/terms/Data Safety/App Store privacy labels signed off | legal drafts exist; legal approval not present | LEGAL_SIGNOFF_REQUIRED |
| RC1-014 | ops readiness | named beta/on-call/support/WAF/rollback evidence | ops runbook exists; owners and WAF/rate limiting evidence not assigned | BLOCKED_EXTERNAL |
| RC1-015 | real-device QA readiness | QA packet and device execution evidence | QA scripts and RC1 packet exist; physical-device execution not verified | NOT_VERIFIED |
| RC1-016 | final release manifest | manifest generated after RC1 build | `docs/release-artifacts-manifest.md` generated; AAB/APK/archive/IPA found | GO |
