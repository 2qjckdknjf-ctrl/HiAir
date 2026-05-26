# Supabase iOS Auth Report (Phase 4)

Date: 2026-05-26
Path: `mobile/ios/HiAir`

## Implemented

- Added Supabase Swift SDK package wiring in `mobile/ios/project.yml`.
- Added URL-scheme callback plumbing (`hiair://auth/callback`) in project config and app entrypoint.
- Introduced Supabase auth service:
  - `mobile/ios/HiAir/Networking/APIClient.swift` (Supabase auth section)
  - Supports:
    - email/password signup
    - email/password login
    - Apple OAuth sign-in
    - Google OAuth sign-in
    - session restore
    - token refresh
    - logout
    - deep-link callback handling

- Updated app session lifecycle:
  - `mobile/ios/HiAir/AppSession.swift`
  - Stores Supabase session data (`userId`, `email`, `accessToken`, `refreshToken`) in secure local storage.
  - Restores existing Supabase session at startup.
  - Reacts to auth session change notifications.

- Updated auth UI:
  - `mobile/ios/HiAir/Screens/AuthView.swift`
  - Signup/login switched to Supabase Auth.
  - Added Apple and Google sign-in actions.

- Updated API bearer refresh path:
  - `mobile/ios/HiAir/Networking/APIClient.swift`
  - Refreshes access token through Supabase session refresh instead of legacy backend refresh endpoint.

## Security checks

- Service-role key is not used in iOS code.
- Only Supabase anon/public key is read from config.
- Backend API calls continue to send `Authorization: Bearer <access_token>`.

## Operational notes

- Real `SUPABASE_URL` and `SUPABASE_ANON_KEY` still need provisioning in app config before runtime testing.
- Apple/Google provider setup in Supabase dashboard is required for successful OAuth flow.
