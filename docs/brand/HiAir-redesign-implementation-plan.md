# HiAir Brand Kit — Implementation Plan

Branch: `feat/hiair-brand-kit-system-redesign`  
Last updated: 2026-05-27

## Affected token files

### iOS (`mobile/ios/HiAir/DesignSystem/`)

- Tokens.swift (legacy AuroraTokens alias)
- HiAirColors.swift
- HiAirGradients.swift
- HiAirTypography.swift
- HiAirSpacing.swift
- HiAirRadius.swift
- HiAirShadow.swift
- HiAirMotion.swift
- HiAirRiskStyle.swift
- HiAirAdaptiveLayout.swift
- HiAirScreenMetrics.swift
- HiAirResponsiveSpacing.swift
- HiAirComponents.swift

### Android (`mobile/android/app/src/main/java/com/hiair/ui/design/`)

- Tokens.kt (expanded)
- HiAirColors.kt … HiAirRiskStyle.kt
- HiAirAdaptiveLayout.kt
- HiAirScreenMetrics.kt
- HiAirResponsiveSpacing.kt
- HiAirComponents.kt

## Affected components

iOS + Android shared component set (background, orb, cards, buttons, risk chips, empty/loading/error).

## Affected screens

| Screen | iOS file | Android file |
|--------|----------|--------------|
| Launch / splash | LaunchScreen.storyboard | themes.xml splash |
| Onboarding | OnboardingView.swift | — (state only on Android) |
| Auth | AuthView.swift | SettingsScreenRenderer.kt |
| Dashboard | DashboardView.swift | DashboardScreenRenderer.kt |
| Daily Planner | DailyPlannerView.swift | PlannerScreenRenderer.kt |
| Symptoms | SymptomLogView.swift | SymptomsScreenRenderer.kt |
| Insights | InsightsView.swift | InsightsScreenRenderer.kt |
| Settings | SettingsView.swift | SettingsScreenRenderer.kt |
| Root shell | RootTabView.swift | AppMainActivity.kt |

## Safe implementation order

1. Brand docs (this folder)
2. Centralize tokens (no screen edits)
3. Adaptive helpers
4. Placeholder brand assets
5. Shared UI components
6. HiAirV2Theme / V2Ui migration to tokens
7. Screen visual refit (wrap, don't rewrite ViewModels)
8. Launch / splash
9. Parity + adaptive QA checklists
10. Design-system guard script
11. Build verification + final report

## Adaptive strategy

- `HiAirScreenMetrics` derives layout mode from width
- Screens apply `hiAirScreenPadding()` / `HiAirAdaptiveLayout.contentMaxWidth`
- Dashboard: single column phones; optional two-column tablet (iOS)
- Hero orb: `min(width * 0.22, 120pt)` compact, up to 160pt tablet
- All scrollable content in ScrollView / ScrollView+LinearLayout

## Visual QA checklist (summary)

See `HiAir-adaptive-qa-checklist.md` and `HiAir-ios-android-parity-checklist.md`.
