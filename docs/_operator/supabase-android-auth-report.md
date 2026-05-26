# Supabase Android Auth Report (Phase 5)

Date: 2026-05-26
Path: `mobile/android/app`

## Implemented

- Added Supabase runtime contract to Android build config:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_REDIRECT_URI`

- Added deep-link callback intent filter:
  - `hiair://auth/callback`
  - File: `mobile/android/app/src/main/AndroidManifest.xml`

- Added Supabase auth service:
  - `mobile/android/app/src/main/java/com/hiair/network/SupabaseAuthService.kt`
  - Supports:
    - email/password signup
    - email/password login
    - Google OAuth launch
    - Apple OAuth launch
    - OAuth callback session extraction
    - refresh token flow
    - sign out
    - secure session persistence via existing `SessionStore`

- Connected app lifecycle to Supabase auth:
  - `AppMainActivity` now:
    - initializes Supabase auth service
    - consumes OAuth callback on launch and `onNewIntent`
    - wires `ApiClient` token refresher through Supabase refresh
  - `ApiClient.configureAuth` now accepts optional refresher callback.

- Updated settings/auth UI flow:
  - `SettingsViewModel` now integrates with Supabase auth service for signup/login/OAuth launch/signout.
  - `SettingsScreenRenderer` now includes Google/Apple OAuth buttons and uses Supabase signout on logout.

## Security checks

- No service-role key in Android app.
- Uses only anon/public Supabase key for client-side auth flows.
- Bearer access token continues to be propagated through `ApiClient`.
- Session storage remains encrypted (`EncryptedSharedPreferences` fallback path unchanged).

## Notes

- OAuth provider success requires dashboard-side provider configuration and redirect URI registration.
- OAuth callback parser currently handles fragment token payload (`#access_token=...` flow).
