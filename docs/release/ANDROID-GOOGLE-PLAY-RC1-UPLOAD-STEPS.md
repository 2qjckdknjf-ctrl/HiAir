# Android Google Play RC1 Upload Steps

Status: BLOCKED_EXTERNAL until Play Console access, signing decision, tester list, and compliance forms are available.

## 1. Required Owner Inputs

- Google Play Console access.
- Confirmed package/application ID: `com.hiair`.
- Play App Signing decision.
- Upload key ownership/recovery plan if applicable.
- Internal tester email list.
- Privacy Policy URL.
- Data Safety and content rating answers approved by owner/legal.

## 2. AAB Path

RC1 AAB:

```text
mobile/android/app/build/outputs/bundle/release/app-release.aab
```

Build command:

```bash
cd mobile/android
./gradlew clean assembleDebug assembleRelease bundleRelease lint
```

## 3. Signing Status

- RC1 build generated `mobile/android/app/build/outputs/bundle/release/app-release.aab`.
- Release APK artifact is `mobile/android/app/build/outputs/apk/release/app-release-unsigned.apk`.
- Play upload signing status is not verified in this environment.

## 4. Play App Signing Decision

Owner must decide:

- enroll in Play App Signing;
- who owns the upload key;
- where upload key and recovery info are stored;
- whether release signing happens locally or in CI.

Do not commit keystores, passwords, or signing secrets.

## 5. Internal Testing Track Steps

1. Open Google Play Console.
2. Create or open the HiAir app.
3. Confirm package name `com.hiair`.
4. Open Testing -> Internal testing.
5. Create a new release.
6. Upload `mobile/android/app/build/outputs/bundle/release/app-release.aab`.
7. Add internal release notes.
8. Save and review the release.
9. Roll out to internal testing after blocking policy items are complete.

## 6. Tester List

1. Create an internal tester list.
2. Add owner-approved tester emails.
3. Save the opt-in link.
4. Confirm at least one tester can open the opt-in link.

## 7. Data Safety Requirement

Complete Data Safety with legal/product approval. Include, as applicable:

- account data;
- health/persona/symptom-related data;
- environmental location inputs;
- notification tokens;
- diagnostics/observability;
- data export and deletion behavior.

## 8. Content Rating Requirement

Complete Play content rating questionnaire before rollout. Save the rating result as evidence.

## 9. Privacy Policy URL Requirement

Add the approved Privacy Policy URL in Play Console. Do not use draft/local URLs for release.

## 10. Evidence to Capture

- Play Console app dashboard screenshot.
- Package name screenshot.
- Play App Signing status screenshot.
- AAB uploaded screenshot.
- Internal tester list and opt-in link.
- Data Safety completion screenshot/export.
- Content rating screenshot.
- Internal testing active release screenshot.

## 11. Known Blockers

- Play Console access not available in this environment.
- Play App Signing/upload-key decision not captured.
- Data Safety and content rating need legal/product confirmation.
- No Play Internal release number exists yet.
