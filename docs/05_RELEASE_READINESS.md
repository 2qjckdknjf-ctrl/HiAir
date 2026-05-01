# 05 Release Readiness

## Automated Gates
- Backend tests: passing.
- Backend gate (`--skip-db`): passing.
- iOS debug and release simulator builds: passing.
- Android test + debug/release assemble + lintDebug: passing.
- Unified gate script: `scripts/release/hiair_final_gate.sh` passing.
- External readiness checker (non-strict): `scripts/release/check_external_readiness.py` available.

## Release Config Safety
- Android release API URL is HTTPS (`build.gradle.kts`).
- Android release cleartext disabled via manifest placeholders.
- iOS release default API URL is HTTPS and non-HTTPS override rejected outside debug.

## Remaining Manual / External
- App Store Connect metadata upload and review notes finalization.
- Google Play Console listing and data safety form finalization.
- APNs/FCM production credential provisioning and live push verification.
- Final legal sign-off for Terms/Privacy wording.
- Real-device QA evidence file: `docs/release/qa/REAL_DEVICE_QA_REPORT.md`.

## Closure Commands
- Informational: `python3 scripts/release/check_external_readiness.py --env-file backend/.env.local`
- Strict closure: `scripts/release/hiair_final_gate.sh --strict-external`
