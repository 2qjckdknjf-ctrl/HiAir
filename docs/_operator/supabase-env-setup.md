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

## Sync secrets from Supabase (Management API)

Project: `hiair-prod` (`qhxesaemlhzwbunpqjoo`, `eu-central-1`).

1. Create a Personal Access Token: https://supabase.com/dashboard/account/tokens
2. Save it locally (never commit):

```bash
mkdir -p ~/.config/hiair
printf 'SUPABASE_ACCESS_TOKEN=<your-pat>\n' > ~/.config/hiair/supabase-credentials.env
chmod 600 ~/.config/hiair/supabase-credentials.env
```

3. Pull API keys + database password into `backend/.env.local`:

```bash
python3 backend/scripts/sync_supabase_secrets.py
```

The script sets `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (legacy or secret), `DATABASE_URL`, `DIRECT_DATABASE_URL`, and leaves `SUPABASE_JWT_SECRET` empty when JWKS verification is used (ES256 on `hiair-prod`).

MCP (`get_publishable_keys`) only returns publishable/anon keys. For fully automated local sync without a PAT, use the one-shot edge bootstrap (already used for `hiair-prod`):

- Edge function `hiair-env-bootstrap` is deployed disabled (HTTP 410) after secrets were pulled.
- Pooler host for `eu-central-1`: `aws-1-eu-central-1.pooler.supabase.com:5432` (not `aws-0`).

Alternative: Management API PAT flow via `backend/scripts/sync_supabase_secrets.py`.
