# HiAir QA Run 006 Report

Date: 2026-04-07  
Scope: mobile auth wiring fixes for core buttons/pages before manual device test

## Problem addressed

After backend hardening, several mobile flows could fail with `401` because auth headers were not attached in all requests.

## Fixes implemented

### iOS

- `APIClient.fetchDashboardOverview(...)` now sends auth headers.
- `APIClient.logSymptom(...)` now sends auth headers.
- `DashboardViewModel.refresh(...)` now receives and uses session auth data.
- `SymptomLogViewModel.submit(...)` now receives and uses session auth data.
- `OnboardingView` no longer overwrites `session.userId` (prevents accidental logout loop).

### Android

- `ApiClient.fetchDashboardOverview(...)` now supports auth headers.
- `ApiClient.logSymptom(...)` now supports auth headers.
- `DashboardViewModel.refresh(...)` now accepts user/session context.
- `SymptomLogViewModel.submit(...)` now requires user/session context.
- `MainActivity` now passes settings session auth data into dashboard/symptom actions.

## Verification

- iOS simulator build:
  - `xcodebuild -project "HiAir.xcodeproj" -scheme "HiAir" -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build` -> passed.
- Android debug build:
  - `./gradlew :app:assembleDebug --no-daemon` -> passed.

## Remaining before full beta manual test

- Real device manual QA matrix from `docs/qa-checklist.md` (buttons/screens/taps end-to-end).
- Store uploads still require Apple/Google account access.
- Legal finalization still pending (`privacy-policy-draft`, `terms-of-service-draft`).
