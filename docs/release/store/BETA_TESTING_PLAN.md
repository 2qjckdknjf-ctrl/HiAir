# Closed Beta Testing Plan

## Cohort
- Target size: 20-50 testers.
- Geography: Spain/Barcelona first-wave.
- Personas:
  - Parents/caregivers
  - Runners
  - Elderly users/caregivers
  - Allergy/asthma-sensitive users
  - Outdoor workers

## Key Metrics
- D1 retention
- D7 retention
- Crash-free sessions
- Alert opt-in rate
- Morning briefing open rate
- Symptom log completion rate
- Support/feedback severity distribution

## Feedback Severity Matrix
- P0: crashes, auth lockouts, privacy/data leakage, wrong-user data.
- P1: broken critical flow (login, dashboard, planner, export/delete).
- P2: UX/localization polish issues.

## Test Scenarios
- Auth lifecycle: signup, login, refresh, logout, session expiry.
- Dashboard + planner with and without profile.
- Symptom logging and insights unlock path.
- Briefing schedule read/update.
- Privacy export + delete account.

## External Blockers
- TestFlight/Play closed-track setup and tester invites.
- Push production credential setup (APNs/FCM) for live delivery validation.
