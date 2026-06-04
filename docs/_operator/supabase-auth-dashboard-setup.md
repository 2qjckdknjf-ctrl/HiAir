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
2. Configure Services ID `com.hiair.app.auth`, team ID `43A4KW5BKB`, key ID, and Sign in with Apple `.p8` from Apple Developer (not the App Store Connect API key).
3. Return URL in Apple must include:
   - `https://qhxesaemlhzwbunpqjoo.supabase.co/auth/v1/callback`

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

## 5) Security hygiene

- Rotate database password after any one-shot env bootstrap edge function was used.
- Delete disabled edge function `hiair-env-bootstrap` in Dashboard → Edge Functions when no longer needed.
- Never commit `backend/.env.local`, service role keys, or DB passwords.
