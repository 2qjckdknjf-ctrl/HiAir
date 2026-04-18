# HiAir Mobile (Native)

This folder contains native client code skeletons for:
- `ios/` (Swift)
- `android/` (Kotlin)

## Current status

- Core network/request models are added for risk flow.
- API client is added for both platforms.
- Onboarding + Dashboard view model skeletons are added for both platforms.
- Dashboard flow on both platforms now uses:
  - `GET /api/dashboard/overview` (single aggregated payload)
- Dashboard models now include daily summary/actions and notification text.
- Symptom log skeleton added on both platforms (`/api/symptoms/log`).
- Settings state now supports backend sync on both platforms (`GET/PUT /api/settings`).
- Daily planner skeleton added on both platforms (`/api/planner/daily`).
- Root navigation shell added on both platforms:
  - iOS `TabView` root
  - Android root shell state/view models
- Device token registration client methods added (`/api/notifications/device-token`).
- Android Gradle project skeleton added in `android/`.
- iOS XcodeGen project spec added in `ios/project.yml`.
- Android `MainActivity` now includes interactive screen shell:
  - Dashboard, Planner, Symptoms, Settings
  - each wired to current ViewModel/network calls.
- iOS flow now uses shared `AppSession` state:
  - onboarding collects persona/location/user/profile ids
  - tabs consume shared session for dashboard/planner/symptoms/settings.

## Next implementation steps

1. iOS:
   - open existing project: `mobile/ios/HiAir.xcodeproj`
   - if Xcode fails to open/build, run:
     - `rm -rf ~/Library/Developer/Xcode/DerivedData/HiAir-*`
     - `xcodebuild -project "HiAir.xcodeproj" -scheme "HiAir" -configuration Debug -destination "generic/platform=iOS Simulator" clean build`
     - `open -a Xcode "mobile/ios/HiAir.xcodeproj"`
2. Android:
   - use Gradle Wrapper from `mobile/android`:
     - `./gradlew :app:assembleDebug --no-daemon`
     - `./gradlew :app:bundleRelease --no-daemon`
     - `./gradlew :app:lintDebug --no-daemon`
   - open `mobile/android` in Android Studio and run `app` module
3. Continue UI wiring:
   - connect navigation shell to real screen composables/views
   - add planner/symptoms/settings full UI (not only state/viewmodel layer)
