# iOS Audit

## Project found

`mobile/ios/HiAir.xcodeproj` and `mobile/ios/project.yml` are present.

## Schemes

`xcodebuild -list -project HiAir.xcodeproj` found scheme `HiAir`.

Status: DONE

## Build status

Initial simulator build failed because `HiAirV2Theme.swift` existed in the source tree but was missing from the checked-in Xcode project sources. The project file was updated and the simulator build then passed.

Status: FIXED

## App flows found

- Auth/signup/login: DONE
- Onboarding: DONE
- Dashboard: DONE
- Planner: DONE
- Symptom log: DONE
- Settings/subscriptions: DONE

## API integration status

`APIClient.swift` centralizes API calls. It supports `HIAIR_API_BASE_URL`, `API_BASE_URL`, and a local default.

Status: PARTIAL

Gap: Release safety depends on build settings/env being correct. `project.yml` includes release `https://api.hiair.app`, but checked-in project drift should be monitored.

## Auth status

Bearer auth is used. No client dependency on legacy `X-User-Id` was found.

Status: DONE

## Risk mapping status

Risk models and UI mapping handle current backend contract paths.

Status: DONE

## Notifications status

API method for device-token registration exists. APNs registration / app delegate / `UNUserNotificationCenter` flow was not found.

Status: MISSING

## Privacy strings status

Generated Info.plist is used. No Core Location usage was found in reviewed code, but privacy strings and App Privacy Manifest still need a store compliance pass.

Status: PARTIAL

## TestFlight readiness

Simulator build: DONE. Signed archive/upload: BLOCKED_EXTERNAL. TestFlight account access, signing, App Store Connect metadata, privacy URLs, screenshots, and legal signoff remain external/manual.

Status: PARTIAL

## Manual QA required

- NEEDS_MANUAL_QA: real-device install and core flow pass.
- NEEDS_MANUAL_QA: notification permission/device-token registration once APNs is wired.
- NEEDS_MANUAL_QA: signed archive and TestFlight upload.

## Fixes applied

- `mobile/ios/HiAir.xcodeproj/project.pbxproj`: added `HiAirV2Theme.swift` to the Screens group and target sources.

## Remaining blockers

- MISSING: APNs registration and notification permission flow.
- BLOCKED_EXTERNAL: Apple Developer/App Store Connect, signing assets, TestFlight upload.
- LEGAL_SIGNOFF_REQUIRED: privacy policy, terms, App Store privacy label answers.
