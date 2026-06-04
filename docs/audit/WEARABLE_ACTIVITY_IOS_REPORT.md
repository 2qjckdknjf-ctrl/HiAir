# Wearable Activity — iOS Report

## Implementation

| Component | Path |
|-----------|------|
| HealthKit service | `mobile/ios/HiAir/Services/HealthKitService.swift` |
| Consent UI | `mobile/ios/HiAir/Screens/WearableConsentView.swift` |
| Dashboard card | `DashboardView.swift` + `WearableLoadCardView` |
| Onboarding step | `OnboardingView.swift` step 5 (health) |
| Settings section | `SettingsView.swift` — Health & Wearables |
| API client | `APIClient.swift` wearable endpoints |
| Models | `RiskModels.swift` wearable payloads |
| Entitlements | `HiAir.entitlements` — HealthKit |
| Usage string | `project.yml` — `NSHealthShareUsageDescription` |

## Capabilities

- Read: stepCount, heartRate, restingHeartRate
- Aggregate-only sync to backend
- States: not connected, connected, denied, unavailable, sync failed

## Graceful Fallback

- App fully functional without HealthKit permission
- Consent skippable in onboarding
- Dashboard card shows connect CTA when not linked

## Tests

No dedicated HealthKit unit tests (requires device/simulator with Health data). Manual QA in `docs/qa-wearable-activity-checklist.md`.
