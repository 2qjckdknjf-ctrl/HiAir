# Supabase Env Setup (Phase 1)

Date: 2026-05-26

## Added Contract Variables

Added to:
- `/.env.example`
- `/backend/.env.staging.example`

Variables:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_JWT_SECRET`
- `DATABASE_URL`
- `DIRECT_DATABASE_URL`
- `HIAIR_AUTH_PROVIDER=supabase`
- `HIAIR_AUTH_LEGACY_ENABLED=false`
- `HIAIR_IOS_URL_SCHEME=hiair`
- `HIAIR_ANDROID_URL_SCHEME=hiair`
- `HIAIR_AUTH_REDIRECT_URI=hiair://auth/callback`

## Security Notes

- No real secrets were added to git.
- `SUPABASE_SERVICE_ROLE_KEY` is marked server-only and must never be shipped to mobile clients.
- `SUPABASE_ANON_KEY` is expected for mobile/public clients.
- `SUPABASE_JWT_SECRET` can be empty if JWT verification is done through Supabase JWKS.

## Runtime Expectations

- Backend uses `DATABASE_URL` (and optional `DIRECT_DATABASE_URL`) for SQL connections.
- Auth provider selection defaults to Supabase via `HIAIR_AUTH_PROVIDER=supabase`.
- Legacy backend password flow is disabled by default via `HIAIR_AUTH_LEGACY_ENABLED=false`.
- Mobile OAuth/deep-link callbacks are standardized on `hiair://auth/callback`.
