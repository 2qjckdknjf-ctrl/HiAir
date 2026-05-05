# HiAir First-Run UX Implementation Report

## What was found
- First-run onboarding existed but was technical and did not explain value in plain product language.
- First screen lacked explicit "what to do now" guidance for new users.
- Critical terms (Risk Score, AQI, PM2.5, ozone, heat index, safe windows) had no built-in explanations.
- No dedicated in-app guide/reference section.
- Empty states were partially generic and not always actionable.
- Onboarding could not be reopened from Settings; logout reset onboarding state.

## What was changed

### 1) First-run onboarding (6 screens)
- Rebuilt onboarding into a 6-step educational flow with permission rationale and persona selection.
- Added first-run persistence and explicit completion flow.
- Added support for opening onboarding again from Settings.

### 2) Dashboard "How to start" checklist
- Added starter checklist for new users:
  - current risk,
  - hourly forecast,
  - recommendations,
  - profile setup,
  - notifications.
- Added per-item completion and manual hide.

### 3) In-UI educational tooltips / info
- Added info affordances for:
  - Risk Score,
  - AQI,
  - PM2.5,
  - ozone,
  - heat index,
  - safe windows,
  - recommendations.
- Added air metrics card to expose AQI/PM2.5/ozone/heat index/humidity with explanations.

### 4) In-app reference (HiAir Guide)
- Added "HiAir Guide" entry in Settings with short human-readable sections:
  - what is HiAir,
  - problems solved,
  - who it helps,
  - reading home screen,
  - terminology and behavior guidance,
  - not-a-medical-device scope.

### 5) Empty states and actionability
- Added/expanded actionable empty states for:
  - missing profile,
  - forecast/API temporary unavailability,
  - notifications off,
  - symptom log start state.
- Added one-tap profile auto-create actions from key screens.

### 6) Localization
- Added RU/EN localization keys for onboarding, checklist, guide, tooltip copy, and new empty states.
- Routed new UX text through localization (no newly introduced hardcoded long-form UX copy).

## Files changed
- `mobile/ios/HiAir/AppSession.swift`
- `mobile/ios/HiAir/Screens/OnboardingView.swift`
- `mobile/ios/HiAir/Screens/RootTabView.swift`
- `mobile/ios/HiAir/Screens/DashboardView.swift`
- `mobile/ios/HiAir/Screens/SettingsView.swift`
- `mobile/ios/HiAir/Screens/DailyPlannerView.swift`
- `mobile/ios/HiAir/Screens/InsightsView.swift`
- `mobile/ios/HiAir/Screens/SymptomLogView.swift`
- `mobile/ios/HiAir/Screens/AuthView.swift`
- `docs/ux-first-run-audit.md`
- `docs/ux-onboarding-help-spec.md`
- `docs/ux-copy-map.md`

## Verification and checks run
- iOS build:
  - `xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build` -> PASS
- Android build:
  - `./gradlew :app:assembleDebug` -> PASS (1 non-blocking warning in existing Android file)
- Backend gate (non-DB):
  - `backend/run_gate.sh --skip-db` -> PASS
- Backend tests:
  - `../.venv/bin/python -m pytest tests/test_alert_and_recommendation.py tests/test_privacy_export_api.py tests/test_privacy_delete_api.py tests/test_auth_hardening.py` -> PASS (14 passed)
- IDE lints on changed iOS files:
  - `ReadLints` -> PASS

## Residual risks / follow-up
- Android has one pre-existing warning in `Tokens.kt` (`hour` unused) that does not block build.
- Onboarding permission step requests permissions directly; UX micro-copy for denied-permission recovery can be expanded later with deep links to system settings.
- Additional UI test automation for first-run flow is recommended (currently validated by build + logic integration, without dedicated XCTest UI scripts in this change).
