# HiAir Store Upload Last Mile

This is the minimal manual step set after local build validation.

## Artifacts ready

- iOS archive: `mobile/ios/build/HiAir.xcarchive`
- Android AAB: `mobile/android/app/build/outputs/bundle/release/app-release.aab`

Generate/refresh manifest before upload:

```bash
python3 mobile/scripts/generate_release_manifest.py --strict
```

Manifest output:
- `docs/release-artifacts-manifest.md`

## TestFlight (Apple)

1. Open Xcode Organizer and select `HiAir.xcarchive`.
2. Distribute App -> App Store Connect -> Upload.
3. In App Store Connect, assign build to Internal Testing group.
4. Paste release notes from `docs/release-notes-template.md`.

## Google Play Internal Test

1. Open Google Play Console -> Internal testing.
2. Create release and upload `app-release.aab`.
3. Add testers list.
4. Publish internal release with notes from `docs/release-notes-template.md`.

## After upload

1. Execute `docs/qa-checklist.md` on real devices.
2. Record defects with `docs/bug-report-template.md`.
3. Publish QA results into the next sequential QA report file (`qa-run-00X-report.md`).
