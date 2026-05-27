# HiAir Adaptive QA Checklist

Branch: `feat/hiair-brand-kit-system-redesign`  
Mode: manual QA + `scripts/capture_hiair_adaptive_qa.sh` (compact / standard / large / tablet)

## iOS simulators

| Device | Status | Notes |
|--------|--------|-------|
| iPhone SE / compact | Captured | `docs/brand/screenshots/ios/compact/dashboard.png` |
| Standard iPhone 15 | Captured | `docs/brand/screenshots/ios/standard/dashboard.png` |
| iPhone Pro Max | Captured | `docs/brand/screenshots/ios/large/dashboard.png` |
| iPad portrait | Pending (simulator boot error on dev machine) | contentMaxWidth 680pt |
| iPad landscape | Pending manual | scroll + max width |
| Dynamic Type large | Pending manual | badges use lineLimit + minimumScaleFactor on score |

## Android emulators

| Device | Status | Notes |
|--------|--------|-------|
| ~360dp phone | Pending manual | COMPACT mode |
| ~390–411dp phone | Build verified | `./gradlew :app:assembleDebug` |
| Large phone | Pending manual | STANDARD mode |
| Tablet 600dp+ | Pending manual | TABLET mode |
| Expanded 840dp+ | Pending manual | EXPANDED mode |
| Font scale 1.3+ | Pending manual | TextView wrap |
| Gesture / 3-button nav | Pending manual | ScrollView bottom padding |

## Screens

| Screen | iOS | Android |
|--------|-----|---------|
| Launch | LaunchScreen.storyboard | Theme.HiAir splash |
| Onboarding | OnboardingView | N/A (state only) |
| Auth | AuthView | Settings auth section |
| Dashboard | DashboardView + adaptive | DashboardScreenRenderer |
| Daily Planner | DailyPlannerView | PlannerScreenRenderer |
| Symptoms | SymptomLogView | SymptomsScreenRenderer |
| Insights | InsightsView | InsightsScreenRenderer |
| Settings | SettingsView | SettingsScreenRenderer |
| Empty/loading/error | HiAir*State views | HiAirComponents |

## Checks per screen

- [ ] No clipped primary text at large accessibility sizes
- [ ] CTA reachable (not under home indicator / nav bar)
- [ ] Risk label + number visible (not color-only)
- [ ] Charts/chips scroll or wrap on narrow width
- [ ] Tablet content centered with max width
- [ ] Background not risk-tinted

## Screenshots

Optional iOS capture:

```bash
scripts/capture_hiair_adaptive_qa.sh
# or single device:
HIAIR_SIM_DEVICE="iPhone 15 Pro Max" HIAIR_OUT_BUCKET=large scripts/capture_hiair_ios_screenshots.sh
```

Output paths:

```
docs/brand/screenshots/ios/{compact,standard,large,tablet}/
docs/brand/screenshots/android/{compact,standard,large,tablet}/
```

Captured 2026-05-27: compact, standard, large dashboard.png (iPad pending — CoreSimulator boot error on dev machine).
