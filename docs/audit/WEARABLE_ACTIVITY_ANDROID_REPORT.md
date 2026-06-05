# Wearable Activity — Android Report

## Implementation

| Component | Path |
|-----------|------|
| Health Connect service | `mobile/android/.../health/HealthConnectService.kt` |
| Dashboard card | `DashboardScreenRenderer.kt` |
| Settings section | `SettingsScreenRenderer.kt` |
| API client | `ApiClient.kt` wearable endpoints |
| ViewModel | `DashboardViewModel.kt`, `SettingsState.kt` |
| Dependency | `androidx.health.connect:connect-client:1.1.0-alpha11` |
| Manifest | `<queries>` for Health Connect package |

## Capabilities

- StepsRecord aggregate API (no double counting)
- HeartRateRecord + RestingHeartRateRecord summaries
- Sync daily aggregates to backend when consent active
- `WearableHealthController` — Health Connect permission launcher via `PermissionController.createRequestPermissionResultContract()`
- `WearableHealthHost` — connect/sync from dashboard and settings

## States

- Health Connect unavailable → install prompt intent available
- Not connected / connected / sync failed — non-blocking

## Parity Notes

- Android onboarding flow still minimal; connect available from dashboard/settings
- compileSdk/targetSdk bumped to 35 for Health Connect client compatibility

## Tests

- `DashboardWearableParsingTest` — wearable API JSON parsing (unit)
