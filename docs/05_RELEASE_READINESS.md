# 05 Release Readiness

## Automated Gates
- Backend tests: passing.
- Backend gate (`--skip-db`): passing.
- iOS debug and release simulator builds: passing.
- Android test + debug/release assemble + lintDebug: passing.
- Unified gate script: `scripts/release/hiair_final_gate.sh` passing.

## Release Config Safety
- Android release API URL is HTTPS (`build.gradle.kts`).
- Android release cleartext disabled via manifest placeholders.
- iOS release default API URL is HTTPS and non-HTTPS override rejected outside debug.

## Remaining Manual / External
- App Store Connect metadata upload and review notes finalization.
- Google Play Console listing and data safety form finalization.
- APNs/FCM production credential provisioning and live push verification.
- Final legal sign-off for Terms/Privacy wording.
