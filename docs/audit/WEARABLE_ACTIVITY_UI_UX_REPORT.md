# Wearable Activity — UI/UX Report

## Flows Added

### Onboarding (iOS)
Step 5: "Подключите здоровье и активность" — Connect / Skip before forecast step.

### Consent modal
`WearableConsentView` — reusable from dashboard settings path.

### Dashboard — "Нагрузка сегодня"
States implemented:

1. Connected with data — steps, HR status, load level, recommendation
2. Not connected — connect CTA
3. Permission denied — open settings CTA
4. Data unavailable / sync failed — weather-only message

### Settings — "Health & Wearables"
- Status display
- Disconnect (revoke consent)
- Delete health data (API + confirmation)

### Risk explanation
`RiskAssessmentResult.personalLoad.explanations` surfaced via air API; mobile shows first explanation on load card.

## Localization

Keys added: RU, EN, ES (iOS `AppSession.swift`; Android `AndroidL10n.kt` ru/en).

## Wellness Copy

All user-facing strings avoid medical diagnosis language per spec.
