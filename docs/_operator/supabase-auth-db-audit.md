# Supabase Auth + DB Audit (Phase 0)

Date: 2026-05-26
Workspace: `/Users/alex/Projects/HIAir`

## Scope

- Locate current auth endpoints and implementation details.
- Inventory current SQL schema under `backend/sql`.
- Identify user-owned tables and privacy-related data surfaces.
- Audit iOS and Android auth/session implementation.
- Capture migration risks before Supabase-first rollout.

## 1) Current Auth Endpoints

Implementation lives in `backend/app/api/auth.py`, mounted via `backend/app/main.py` at `/api`.

- `POST /api/auth/signup`
  - Creates row in `users` with local password hash.
  - Issues local JWT access token (`JWT_SECRET`) and local refresh token (`auth_refresh_tokens`).
- `POST /api/auth/login`
  - Verifies local `users.password_hash`.
  - Issues local JWT + local refresh token.
- `POST /api/auth/refresh`
  - Rotates local refresh token from `auth_refresh_tokens`.
  - Issues new local JWT.
- `POST /api/auth/logout`
  - Revokes local refresh token.
- `GET /api/auth/me`
  - Returns only `{"user_id": ...}` from token.

Auth dependency (`backend/app/api/deps.py`):
- Accepts `Authorization: Bearer <token>`.
- Decodes locally issued JWT via `decode_access_token`.
- Validates user existence in `users` table.
- No Supabase JWT verification yet.

## 2) Current DB Schema (`backend/sql`)

Discovered SQL files:
- `001_init.sql`
- `002_subscription_and_access_hardening.sql`
- `003_ai_mvp_architecture.sql`
- `004_ai_observability.sql`
- `005_i18n_preferred_language.sql`
- `006_personal_correlations.sql`
- `007_briefing_schedule.sql`
- `008_auth_refresh_tokens.sql`

Core auth/user model is local-first:
- `users(id, email, password_hash, created_at)`
- `auth_refresh_tokens(...)` references `users(id)`

No `auth.users` references and no RLS policies currently in migration files.

## 3) User-Owned Tables Inventory

### Present (same/similar names)

- `users` (local auth users)
- `profiles` (`user_id -> users.id`)
- `symptom_logs` (currently profile-owned via `profile_id`; no direct `user_id`)
- `risk_scores` (currently profile-owned via `profile_id`; no direct `user_id`)
- `notification_events` (profile-owned via `profile_id`)
- `user_settings` (maps to requested `settings`)
- `push_device_tokens` (maps to requested `device_tokens`)
- `user_subscriptions` (maps to requested `subscriptions`)
- `notification_delivery_attempts` (user-related delivery history)
- `auth_refresh_tokens` (legacy refresh tokens)

### Privacy/export/delete related surfaces

Primary code paths:
- `backend/app/api/privacy.py`
- `backend/app/services/privacy_repository.py`

Export currently includes:
- user, profiles, user_settings, user_subscriptions, briefing_schedule
- symptom_logs, risk_scores, notification_events
- risk_assessments, ai_recommendations, alert_events, ai_explanation_events
- personal_correlations
- push_device_tokens, notification_delivery_attempts
- auth_refresh_tokens, subscription_webhook_events

Delete-account currently:
- Deletes `ai_explanation_events` by profile IDs
- Deletes `notification_events` via profile join
- Deletes `users` row (cascade handles some but not all cross-table ownership semantics)

## 4) iOS Auth/Session Implementation

Main files:
- `mobile/ios/HiAir/AppSession.swift`
- `mobile/ios/HiAir/Networking/APIClient.swift`
- `mobile/ios/HiAir/Screens/AuthView.swift`

Current state:
- Custom backend auth only (`/api/auth/signup`, `/api/auth/login`, `/api/auth/refresh`).
- Stores `userId/accessToken/refreshToken` in Keychain/UserDefaults mix.
- API client sends `Authorization: Bearer <access_token>`.
- Auto-refreshes by calling backend `/api/auth/refresh`.
- No Supabase SDK integration.
- No Apple Sign In / Google Sign In integration.
- No deep-link callback handling (`hiair://auth/callback`) yet.

## 5) Android Auth/Session Implementation

Main files:
- `mobile/android/app/src/main/java/com/hiair/SessionStore.kt`
- `mobile/android/app/src/main/java/com/hiair/network/ApiClient.kt`
- `mobile/android/app/src/main/java/com/hiair/ui/settings/SettingsState.kt`
- `mobile/android/app/src/main/AndroidManifest.xml`

Current state:
- Custom backend auth only (`/api/auth/signup`, `/api/auth/login`, `/api/auth/refresh`).
- Session stored in `EncryptedSharedPreferences` fallbacking to plain shared prefs.
- API client sends `Authorization: Bearer <access_token>`.
- Auto-refreshes by backend `/api/auth/refresh`.
- No Supabase Kotlin SDK integration.
- No Google/Apple auth integration.
- No deep-link intent filter for `hiair://auth/callback`.

## 6) Gaps vs Target Supabase-First Architecture

1. Auth source of truth is local `users/password_hash`, not Supabase Auth.
2. DB user ownership references `users(id)` instead of `auth.users(id)`.
3. No RLS on user-owned tables.
4. `symptom_logs` and `risk_scores` do not carry direct `user_id`.
5. Mobile auth flows are backend-credentials based, no Supabase SDK, no OAuth deep links.
6. `/api/auth/me` is too minimal and does not return profile/subscription context.
7. Privacy flows assume legacy user table semantics.

## 7) Migration Risks and Constraints

- Existing APIs must remain stable for clients during transition.
- Legacy local JWT and refresh token flows currently coupled to many tests.
- Privacy export/delete touches many tables and requires strict ownership consistency after migration.
- Mobile app currently has no social auth SDK plumbing; must add safely without exposing service role key.

## 8) Immediate Next Execution Plan

1. Phase 1: add Supabase env contract to root/backend examples and operator doc.
2. Phase 2: add `003_supabase_auth_rls.sql` to re-key user-owned tables to `auth.users`, add indexes, RLS, policies.
3. Phase 3: add Supabase JWT verifier service, wire FastAPI auth dependency with feature-flagged legacy fallback, update `/api/auth/me` and privacy endpoints.
4. Phase 4/5: implement Supabase auth/session in iOS and Android with deep-link callback and bearer propagation.
5. Phase 6/7: extend tests, run gates, and update architecture/docs/checklists.
