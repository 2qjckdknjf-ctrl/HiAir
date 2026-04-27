# Android Play Internal testing — RC upload steps

Generic RC companion to `docs/release/ANDROID-GOOGLE-PLAY-RC1-UPLOAD-STEPS.md`.

## Status

**BLOCKED_EXTERNAL** until Play Console app exists, signing keys are registered, and compliance forms are completed.

## Do not commit

- Upload keystore, keystore passwords, `google-services.json` from production Firebase, or Play API service account JSON with release permissions.

## AAB path

```text
mobile/android/app/build/outputs/bundle/release/app-release.aab
```

## Build command

```bash
cd mobile/android
./gradlew clean assembleDebug assembleRelease bundleRelease lint
```

## Play Console checklist (summary)

1. Create application id `com.hiair` (or open existing).
2. Enroll in Play App Signing; store upload key outside git.
3. Internal testing track → new release → upload AAB.
4. Complete Data Safety, content rating, privacy policy URL (legal signoff).
5. Add tester emails; distribute opt-in link.

## Full detail

See **`docs/release/ANDROID-GOOGLE-PLAY-RC1-UPLOAD-STEPS.md`** and **`docs/release/GOOGLE-PLAY-INTERNAL-BETA-LAUNCH-PACKET.md`**.
