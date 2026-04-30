# HiAir Release Notes — Aurora Calm v2 + Insights

Date: 2026-05-01  
Branch: `feat/aurora-calm-v2-and-insights`

## Highlights

- Aurora Calm v2 visual system landed on iOS and Android (tokens, time-of-day backgrounds, atmospheric layer, risk-reactive globe).
- Dashboard, Planner, and Symptoms screens were redesigned for calmer hierarchy and better at-a-glance actions.
- New Insights tab shipped on both clients with Personal Patterns rendering.
- Morning Briefing scheduling shipped end-to-end: backend API + mobile settings controls.

## Backend

- Added personal correlations persistence and API:
  - `backend/sql/006_personal_correlations.sql`
  - `backend/app/api/insights.py`
  - `backend/app/services/correlation_engine.py`
  - `backend/app/services/insights_repository.py`
- Added morning briefing persistence, service, and API:
  - `backend/sql/007_briefing_schedule.sql`
  - `backend/app/api/briefings.py`
  - `backend/app/services/briefing_repository.py`
  - `backend/app/services/briefing_service.py`
  - `backend/scripts/dispatch_briefings.py`
- Expanded verification scripts:
  - `backend/scripts/smoke_db_flow.py` now checks insights + briefing endpoints.
  - `backend/scripts/beta_preflight.py` now checks insights + briefing endpoints.

## Mobile

- iOS:
  - Added Aurora design system files under `mobile/ios/HiAir/DesignSystem/`.
  - Added `InsightsView` and integrated it into tab navigation.
  - Added Morning Briefing controls in `SettingsView`.
  - Added explicit loading/error/empty UX polish for new Insights flow.
- Android:
  - Added design token/background components under `mobile/android/app/src/main/java/com/hiair/ui/design/`.
  - Added `InsightsScreenRenderer` and tab entry.
  - Added Morning Briefing controls in `SettingsScreenRenderer`.
  - Added explicit loading/error/empty UX polish for Insights.

## Verification snapshot

- `python3 -m compileall backend/app backend/scripts` — pass.
- `./gradlew :app:compileDebugKotlin` — pass.
- `xcodebuild -project HiAir.xcodeproj -scheme HiAir -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO` — pass.
- Focused backend tests (insights/briefings/correlation/due-logic) — pass.

## Known blockers

- Local end-to-end DB smoke remains blocked when Postgres is unavailable.
- Strict env gate remains blocked without required secure variables (for example `JWT_SECRET`).
- Full CI evidence and device push proof remain pending in this branch cycle.
