# Supabase RLS Migration Report (Phase 2)

Date: 2026-05-26
Migration file: `backend/sql/003_supabase_auth_rls.sql`

## What was introduced

- Added Supabase-first migration to align ownership with `auth.users(id)`.
- Added direct `user_id` ownership to profile-owned tables:
  - `symptom_logs.user_id`
  - `risk_scores.user_id`
  - `notification_events.user_id`
- Backfilled new `user_id` values from `profiles.user_id`.
- Updated key schema defaults/types:
  - `profiles.id`, `symptom_logs.id`, `risk_scores.id` now default to `gen_random_uuid()`
  - `risk_scores.score_value` changed to `numeric`
  - `risk_scores.recommendations_json` defaulted to `'[]'::jsonb`
  - `profiles.updated_at` added

## Ownership FK changes

Foreign keys now target Supabase auth users:
- `profiles.user_id -> auth.users(id)`
- `symptom_logs.user_id -> auth.users(id)`
- `risk_scores.user_id -> auth.users(id)`
- `notification_events.user_id -> auth.users(id)`
- `user_settings.user_id -> auth.users(id)`
- `push_device_tokens.user_id -> auth.users(id)`
- `user_subscriptions.user_id -> auth.users(id)`
- `briefing_schedule.user_id -> auth.users(id)`

## Indexes added/normalized

- `profiles(user_id)`
- `symptom_logs(user_id, created_at desc)`
- `symptom_logs(profile_id, created_at desc)`
- `risk_scores(user_id, created_at desc)`
- `risk_scores(profile_id, created_at desc)`
- `notification_events(user_id, created_at desc)`
- `push_device_tokens(user_id)`
- `user_subscriptions(user_id)`

## RLS coverage

Enabled RLS and added own-row policies (select/insert/update/delete) for:
- `profiles`
- `symptom_logs`
- `risk_scores`
- `notification_events`
- `user_settings`
- `push_device_tokens`
- `user_subscriptions`
- `briefing_schedule`

Policy guard pattern:
- `TO authenticated`
- `(select auth.uid()) = user_id`

## Notes

- Migration keeps legacy table names (e.g., `user_settings`, `push_device_tokens`) to avoid API breakage while moving ownership to Supabase.
- Existing app/repository code still requires backend integration updates to fully operate on Supabase JWT identity (Phase 3).
