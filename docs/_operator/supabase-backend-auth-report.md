# Supabase Backend Auth Report (Phase 3)

Date: 2026-05-26

## Implemented

- Added Supabase JWT validation service:
  - `backend/app/services/supabase_auth.py`
  - Supports secure verification via:
    - `SUPABASE_JWT_SECRET` (HS256)
    - Supabase JWKS (`/auth/v1/.well-known/jwks.json`) fallback
  - Extracts `sub` as `user_id`, `email` claim, and normalized auth context.

- Upgraded auth dependency layer:
  - `backend/app/api/deps.py`
  - Added `AuthContext` with `user_id`, `email`, `provider`, `claims`.
  - Added `get_current_auth_context`.
  - `get_current_user_id` now derives from `AuthContext`.
  - Supabase-first behavior:
    - Uses Supabase validation when `HIAIR_AUTH_PROVIDER=supabase`.
    - Supports feature-flagged fallback to legacy JWT when `HIAIR_AUTH_LEGACY_ENABLED=true`.
    - Transitional local fallback to legacy path when `SUPABASE_URL` is not configured.

- Updated `/api/auth` behavior:
  - `backend/app/api/auth.py`
  - Legacy endpoints (`signup/login/refresh/logout`) are blocked with HTTP 410 when Supabase is active and legacy is disabled.
  - `/api/auth/me` now returns:
    - `user_id`
    - `email`
    - `profile` (first app profile when present)
    - `subscription` status snapshot
    - `auth_provider`

- Updated runtime settings contract:
  - `backend/app/core/settings.py`
  - Added Supabase/auth-provider fields and protected-env validation for Supabase URL.

- Privacy flow alignment with Supabase user IDs:
  - `backend/app/services/privacy_repository.py`
  - Export no longer hard-requires local `users` row if user-owned data exists.
  - Delete-account now removes user-owned rows by `user_id` across app tables and returns success when data was deleted.

## Security posture

- Service-role key remains server-only; no mobile usage added in backend.
- Authorization decisions use JWT `sub` ownership.
- Supabase-first mode is controlled via env flags.

## Remaining backend follow-ups

- Optional hardening: validate Supabase `session_id` against `auth.sessions` for high-sensitivity operations.
- Optional enhancement: enrich `/api/auth/me` with deterministic profile selection policy when multiple profiles exist.
