# HiAir Phase 0 AI Audit (2026-04-07)

## What exists

- Mobile stack:
  - iOS: SwiftUI app with tab navigation (`Dashboard`, `Planner`, `Symptoms`, `Settings`).
  - Android: Kotlin app with API client + ViewModel/state-driven screens.
- Backend stack:
  - FastAPI app (`backend/app/main.py`) with modular routers.
  - Service/repository layering for risk, notifications, auth, subscription, privacy.
- Database:
  - PostgreSQL schema via SQL migrations (`001`, `002`).
  - Existing entities: `users`, `profiles`, `environment_snapshots`, `risk_scores`,
    `symptom_logs`, `notification_events`, `user_settings`, push/subscription tables.
- API architecture:
  - REST endpoints under `/api/*` with auth dependency (`Bearer` JWT and fallback `X-User-Id`).
  - Existing risk/planner/dashboard/recommendation/notifications APIs.
- State management:
  - iOS: `ObservableObject` + `@Published` + `AppSession`.
  - Android: state classes + ViewModel-style classes.
- Current auth:
  - Email/password auth with JWT issuance and `GET /api/auth/me`.
- Integrations:
  - Weather: OpenWeather/Open-Meteo.
  - AQI: WAQI/Open-Meteo.
  - Notifications: stub/live provider abstraction (FCM/APNs).
- Observability/logging:
  - Request logging middleware + `/api/observability/metrics`.
  - Notification delivery attempts and rotation event logs persisted.

## What is reusable for AI layer

- Existing deterministic risk baseline (`risk_engine.py`) and planner concepts.
- Existing profile ownership checks and auth guardrails.
- Existing environment provider adapters and DB repositories.
- Existing notification persistence model and dispatch workflow.
- Existing symptom logging and settings plumbing in backend and mobile UI.

## What is missing (before this implementation)

- No dedicated deterministic personal risk interpreter returning structured AI-ready object
  (`overallRisk/heatRisk/airRisk/safeWindows/reasonCodes`).
- No profile-aware recommendation engine separated from the old generic recommendation function.
- No alert orchestration with cooldown + dedupe + quiet hours as first-class policy.
- No AI explanation layer with strict prompt/output guardrails and fallback mode.
- Existing schema lacked several AI-MVP fields:
  - profile context fields (`profile_type`, sensitivities, timezone metadata),
  - expanded environmental fields (`feels_like`, `pm10`, `uv`, `wind_speed`, geolocation),
  - dedicated `risk_assessments`, `ai_recommendations`, `alert_events`.
- No API surface matching required contracts (`/api/air/*`, `/api/alerts/evaluate`,
  `POST /api/symptoms`, `GET /api/symptoms/history`).
- UI did not yet render AI-structured card/timeline on top of deterministic AI contracts.

## Blockers and constraints discovered

- `profiles` table already existed with older schema; required non-breaking extension instead of replacement.
- Existing mobile clients rely on legacy endpoints/fields; backward compatibility had to be preserved.
- LLM credentials may be unavailable in runtime; explanation layer must degrade gracefully.
- Existing project had no backend test suite; deterministic core tests had to be introduced from scratch.

## Implementation path used

1. Extend schema in-place with additive migration (`003_ai_mvp_architecture.sql`).
2. Introduce deterministic AI domain models and services without breaking legacy endpoints.
3. Add required `/api/air/*` and `/api/alerts/evaluate` contracts.
4. Add AI guardrailed explanation layer with template fallback.
5. Wire MVP UI integration in iOS screens (risk card, timeline, alert preferences, quick symptom log).
6. Add focused tests for deterministic risk core and day-plan generation.
