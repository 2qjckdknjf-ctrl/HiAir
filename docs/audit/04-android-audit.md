# Android Audit

## Project found

Android project root: `mobile/android`

## Gradle structure

Single module `:app` with `settings.gradle.kts`, root `build.gradle.kts`, and `app/build.gradle.kts`. Gradle wrapper is present.

Status: DONE

## Build status

`./gradlew assembleDebug assembleRelease lint` completed successfully.

Status: DONE

## Lint status

`lint` completed successfully.

Status: DONE

## App flows found

- Auth in settings flow: PARTIAL
- Onboarding state model: MISSING as wired product flow
- Dashboard: PARTIAL
- Planner: DONE
- Symptom log: DONE
- Settings: DONE
- Subscriptions scaffold: DONE

## API integration status

`AppConfig.kt` and `BuildConfig.API_BASE_URL` centralize base URL. Debug uses emulator localhost; release uses `https://api.hiair.app`.

Status: DONE

## Auth status

Bearer auth is used. No legacy `X-User-Id` client dependency found.

Status: DONE

## Risk mapping status

Android risk models exist and align with backend response shape.

Status: DONE

## Notifications status

Backend API method for device-token registration exists, but no Firebase/FCM dependency or token registration call was found.

Status: MISSING

## Google Play readiness

Builds pass, but signed AAB/upload, Play Console access, Data Safety, screenshots, final store metadata, and release signing proof remain unresolved.

Status: PARTIAL

## Manual QA required

- NEEDS_MANUAL_QA: real-device install and core flow pass.
- NEEDS_MANUAL_QA: signed AAB verification.
- NEEDS_MANUAL_QA: Google Play Internal Test upload and tester group setup.
- NEEDS_MANUAL_QA: notification E2E after FCM integration.

## Fixes applied

- `mobile/android/app/src/main/AndroidManifest.xml`: set `android:allowBackup="false"` to reduce token/session backup risk.

## Remaining blockers

- MISSING: FCM dependency/token registration and Android 13+ notification permission strategy.
- PARTIAL: onboarding/auth gating differs from iOS and needs product QA.
- BLOCKED_EXTERNAL: Google Play Console, signing key governance, Data Safety signoff.
