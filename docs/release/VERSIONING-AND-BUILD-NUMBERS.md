# Versioning and Build Numbers

RC label: `closed-beta-rc1`

## Backend

| Field | Value | Status |
| ----- | ----- | ------ |
| FastAPI app version | `0.1.0` from `backend/app/main.py` | GO |
| Explicit package/app version source | Not found beyond FastAPI metadata | NEEDS_OWNER_DECISION |
| Prompt/config versions | `hiair-expl-v1` and threshold `v1-rule-based` are internal model/config versions, not release versions | INFO |

## iOS

| Field | Value | Status |
| ----- | ----- | ------ |
| Bundle ID | `com.hiair.app` | GO |
| Marketing version | `0.1.0` | GO |
| Build number | `1` | GO |
| Source files | `mobile/ios/HiAir.xcodeproj/project.pbxproj`, `mobile/ios/project.yml` | GO |

## Android

| Field | Value | Status |
| ----- | ----- | ------ |
| namespace | `com.hiair` | GO |
| applicationId | `com.hiair` | GO |
| versionName | `0.1.0` | GO |
| versionCode | `1` | GO |
| Source file | `mobile/android/app/build.gradle.kts` | GO |

## Before the Next Upload

- Keep RC1 as `closed-beta-rc1` unless the owner intentionally creates `closed-beta-rc2`.
- Increment iOS `CURRENT_PROJECT_VERSION` before uploading another TestFlight build with the same marketing version.
- Increment Android `versionCode` before uploading another Google Play build.
- Decide whether backend release versioning should remain FastAPI metadata only or gain an explicit repo-level version file.
- Do not change production secrets or production deployment configuration as part of version bumping.
