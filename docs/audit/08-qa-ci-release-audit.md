# QA / CI / Release Audit

## Summary

Backend tests, Android build/lint, and iOS simulator build were verified locally. Release manifest generation ran and reported missing iOS IPA. Store readiness remains blocked by external account/legal/metadata work.

## CI found

- `.github/workflows/backend-ci.yml`
- `.github/workflows/android-ci.yml`
- `.github/workflows/ios-ci.yml`
- `.github/workflows/external-blocker-ops.yml`

Status: DONE

## QA assets found

- `docs/qa-checklist.md`
- `docs/qa-run-001-report.md` through `docs/qa-run-006-report.md`
- `docs/beta-cycle-001-report.md`
- `docs/beta-cycle-002-report.md`

Status: DONE

## Release assets found

- `docs/release-notes-template.md`
- `docs/release-package-2026-04-07.md`
- `docs/release-artifacts-manifest.md`
- `docs/store-upload-last-mile.md`
- `docs/store-metadata-packet.md`
- `mobile/scripts/generate_release_manifest.py`

Status: PARTIAL

## Commands executed

| Command | Result | Status |
|---|---|---|
| `cd backend && ../.venv/bin/python -m pytest -q` | `30 passed` | DONE |
| `cd mobile/android && ./gradlew assembleDebug assembleRelease lint` | `BUILD SUCCESSFUL` | DONE |
| `cd mobile/ios && xcodebuild -list -project HiAir.xcodeproj` | Scheme `HiAir` found | DONE |
| `cd mobile/ios && xcodebuild ... iphonesimulator build CODE_SIGNING_ALLOWED=NO` | Initial fail, then passed after project source fix | FIXED |
| `python3 mobile/scripts/generate_release_manifest.py --strict` | Found Android AAB/debug APK/iOS archive; missing iOS IPA | PARTIAL |

## Release blockers

- BLOCKED_EXTERNAL: Apple Developer/App Store Connect access.
- BLOCKED_EXTERNAL: Google Play Console access.
- BLOCKED_EXTERNAL: signed release credentials.
- LEGAL_SIGNOFF_REQUIRED: final legal text and privacy labels.
- MISSING: iOS IPA artifact.
- NEEDS_MANUAL_QA: real-device QA matrix.

## Fixes applied

- iOS build source membership fixed.
- Android backup security hardened.
- Backend ops gate hardened and documented.

## Remaining blockers

Closed beta is NEAR-GO if local DB smoke/API preflight and external account/legal conditions are accepted as blockers. Public launch is NO-GO.
