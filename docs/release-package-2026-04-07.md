# HiAir Release Package (2026-04-07)

Prepared for manual upload to TestFlight and Google Play Internal Testing.

## Build artifacts

- iOS archive: `mobile/ios/build/HiAir.xcarchive`
- Android AAB: `mobile/android/app/build/outputs/bundle/release/app-release.aab`
- Android debug APK: `mobile/android/app/build/outputs/apk/debug/app-debug.apk`
- Artifact manifest (sizes + SHA256): `docs/release-artifacts-manifest.md`

## Backend readiness evidence

- QA run 003 (CI hardening): `docs/qa-run-003-report.md`
- QA run 004 (backend gate + mobile build checks): `docs/qa-run-004-report.md`
- QA run 005 (artifact manifest automation): `docs/qa-run-005-report.md`
- Latest handoff summary: `docs/next-agent-handoff.md`

## Required manual steps (access needed)

### Apple TestFlight
1. Open Xcode Organizer and select `mobile/ios/build/HiAir.xcarchive`.
2. Distribute App -> App Store Connect -> Upload.
3. Assign build to Internal Testing group.
4. Use notes from `docs/release-notes-template.md`.

### Google Play Internal Test
1. Open Google Play Console -> Internal testing.
2. Upload `mobile/android/app/build/outputs/bundle/release/app-release.aab`.
3. Add tester list and publish internal release.
4. Use notes from `docs/release-notes-template.md`.

## Post-upload mandatory QA

- Execute `docs/qa-checklist.md` on real devices.
- Log defects with `docs/bug-report-template.md`.
- Publish next run report as `docs/qa-run-006-report.md`.

## Known blockers outside engineering code

- Apple/Google account access for upload.
- Legal final review of:
  - `docs/privacy-policy-draft.md`
  - `docs/terms-of-service-draft.md`
