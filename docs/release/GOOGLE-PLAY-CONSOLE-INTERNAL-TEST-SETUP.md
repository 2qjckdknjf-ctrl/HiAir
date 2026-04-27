# Google Play Console Internal Test Setup

Status: BLOCKED_EXTERNAL until the owner provides Play Console access, signing ownership, tester list, and store compliance answers.

## 1. Create App

1. Sign in to Google Play Console.
2. Create a new app.
3. Select app name, default language, app/game type, and free/paid setting.
4. Confirm declarations requested by Play Console.
5. Save evidence: app dashboard screenshot.

## 2. Confirm Package Name

1. Confirm the Android package name in the app manifest and Gradle config.
2. Use the same package name when registering Firebase and Play Console assets.
3. Save evidence: Play Console package name screenshot.

## 3. Play App Signing

1. Decide whether to enroll in Play App Signing.
2. If enrolled, preserve upload key ownership and recovery details in the owner password manager.
3. Do not commit keystore files, keystore passwords, or upload-key secrets.
4. Save evidence: Play App Signing status screenshot.

## 4. Build AAB

From repo root:

```bash
cd mobile/android
./gradlew assembleDebug assembleRelease bundleRelease lint
```

Current artifact path:

```text
mobile/android/app/build/outputs/bundle/release/app-release.aab
```

Expected evidence:

- Gradle exits with `BUILD SUCCESSFUL`.
- AAB exists at the path above.

## 5. Internal Testing Release

1. Open Testing -> Internal testing.
2. Create or select an internal testing track.
3. Create a new release.
4. Upload `mobile/android/app/build/outputs/bundle/release/app-release.aab`.
5. Add release notes for internal testers.
6. Save the draft release.

Expected evidence:

- AAB uploaded successfully.
- Internal release draft exists.

## 6. Testers

1. Create an internal tester email list.
2. Add owner-approved tester emails.
3. Copy the opt-in link after release rollout.
4. Save evidence: tester list screenshot and opt-in link.

## 7. Data Safety

1. Complete Data Safety based on the approved privacy/legal packet.
2. Include account data, health/environment data, device identifiers, notification tokens, diagnostics, and deletion/export behavior as applicable.
3. Do not guess legal answers. Mark unresolved items as LEGAL_SIGNOFF_REQUIRED.
4. Save evidence: completed Data Safety screenshot/export.

## 8. Content Rating and Policy

1. Complete content rating questionnaire.
2. Add privacy policy URL.
3. Complete target audience, ads, data collection, and health-related declarations if prompted.
4. Save evidence: completed policy checklist screenshot.

## 9. Rollout to Internal Testing

1. Review release warnings.
2. Resolve blocking Play Console errors.
3. Roll out to internal testing.
4. Confirm testers can access the opt-in page.

Expected evidence:

- Release status is active or available for internal testing.
- Tester opt-in link opens.
- At least one tester installs the app successfully.
