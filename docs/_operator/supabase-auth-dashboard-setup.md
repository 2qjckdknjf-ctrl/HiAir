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

## 2) Google provider

Auth → Providers → Google:

1. Enable Google.
2. Paste OAuth client ID/secret from Google Cloud Console.
3. Authorized redirect URI in Google must include:
   - `https://qhxesaemlhzwbunpqjoo.supabase.co/auth/v1/callback`

## 3) Apple provider

Auth → Providers → Apple:

1. Enable Apple.
2. Configure Services ID, team ID, key ID, and private key (.p8) from Apple Developer.
3. Return URL in Apple must include:
   - `https://qhxesaemlhzwbunpqjoo.supabase.co/auth/v1/callback`

## 4) Post-config verification

- iOS: email/password sign-in, Google/Apple OAuth, session restore, refresh, logout (`mobile/ios`).
- Android: same flows (`mobile/android`).
- Backend: `cd backend && .venv/bin/python -m pytest tests/test_supabase_auth_integration.py -q --no-cov`

## 5) Security hygiene

- Rotate database password after any one-shot env bootstrap edge function was used.
- Delete disabled edge function `hiair-env-bootstrap` in Dashboard → Edge Functions when no longer needed.
- Never commit `backend/.env.local`, service role keys, or DB passwords.
