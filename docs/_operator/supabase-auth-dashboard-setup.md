# Supabase Auth Dashboard Setup (hiair-prod)

Project: `hiair-prod` (`qhxesaemlhzwbunpqjoo`)  
Dashboard: https://supabase.com/dashboard/project/qhxesaemlhzwbunpqjoo/auth/url-configuration

## 1) URL configuration

Set **Site URL** (staging/local example):

- `http://localhost:3000` (optional web) or your marketing site when available

**Redirect URLs** (allow list):

- `hiair://auth/callback`
- `com.hiair://auth/callback` (Android alternate, if used by platform)
- `https://qhxesaemlhzwbunpqjoo.supabase.co/auth/v1/callback` (Supabase default; keep if using hosted OAuth return)

## 2) Google provider (required for “Sign in with Google”)

Auth → Providers → Google:

1. **Enable** Google (if disabled, the app shows `provider is not enabled`).
2. Paste OAuth client ID/secret from Google Cloud Console.
3. Authorized redirect URI in Google must include:
   - `https://qhxesaemlhzwbunpqjoo.supabase.co/auth/v1/callback`

## 3) Apple provider (required for “Sign in with Apple”)

Auth → Providers → Apple:

1. **Enable** Apple (if disabled, native Sign in with Apple fails at Supabase).
2. **Client IDs** (comma-separated): `com.hiair.app,com.hiair.app.auth`
3. **Secret Key**: JWT generated from `AuthKey_8BXW8SG2B4.p8` (not the raw `.p8` file).
4. Apple Developer: Services ID `com.hiair.app.auth`, Team `43A4KW5BKB`, Key ID `8BXW8SG2B4`.
5. Return URL in Apple must include:
   - `https://qhxesaemlhzwbunpqjoo.supabase.co/auth/v1/callback`

Automated setup (requires [account PAT](https://supabase.com/dashboard/account/tokens), not service_role JWT):

```bash
# Key stored at backend/.secrets/AuthKey_8BXW8SG2B4.p8
python3 scripts/ops/configure_supabase_apple_provider.py
```

Dry-run / dashboard paste only:

```bash
python3 scripts/ops/configure_supabase_apple_provider.py --dry-run
# Secret written to backend/.secrets/apple_signin_client_secret.jwt
```

## 3b) Telegram

Supabase Auth does **not** ship a `telegram` OAuth provider on `hiair-prod`. The iOS app exposes **Google**, not Telegram. Use email/password or Apple/Google OAuth.

## 3c) Redirect URLs (script)

```bash
bash scripts/ops/configure_supabase_auth_urls.sh
```

Requires `SUPABASE_ACCESS_TOKEN` in `~/.config/hiair/supabase-credentials.env`.

## 4) Post-config verification

- iOS: email/password sign-in, Google/Apple OAuth, session restore, refresh, logout (`mobile/ios`).
- Android: same flows (`mobile/android`).
- Backend: `cd backend && .venv/bin/python -m pytest tests/test_supabase_auth_integration.py -q --no-cov`

## 5) TestFlight email login (backend bridge)

Production API exposes `POST /api/auth/supabase/session` when the backend has **legacy JWT** keys:

- `SUPABASE_ANON_KEY` → `eyJ...` (same as iOS `INFOPLIST_KEY_SUPABASE_ANON_KEY`)
- `SUPABASE_SERVICE_ROLE_KEY` → `eyJ...` (Dashboard → Project Settings → API → **service_role** legacy)

`sb_publishable_*` / `sb_secret_*` keys do **not** work with GoTrue admin APIs.

**Service role JWT** (not the dashboard PAT): Project Settings → API → legacy **service_role** → store in `backend/.env.local` as `SUPABASE_SERVICE_ROLE_KEY=eyJ...` (same value as iOS anon style JWT). Optional copy path: `~/.config/hiair/supabase-credentials.env` as `SUPABASE_SERVICE_ROLE_JWT`.

Full sync (needs [account PAT](https://supabase.com/dashboard/account/tokens) in `SUPABASE_ACCESS_TOKEN`):

```bash
python3 backend/scripts/sync_supabase_secrets.py
./scripts/ops/deploy_hiair_api_cloudflare.sh
```

Until keys are fixed, use **email signup → confirm link in inbox → Log in** in the TestFlight build.

## 6) Security hygiene

- Rotate database password after any one-shot env bootstrap edge function was used.
- Delete disabled edge function `hiair-env-bootstrap` in Dashboard → Edge Functions when no longer needed.
- Never commit `backend/.env.local`, service role keys, or DB passwords.
