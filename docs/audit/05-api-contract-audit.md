# API Contract Audit

## Summary

Backend, iOS, and Android share a broad API contract. Mobile clients use bearer auth and centralized base URLs. No active mobile dependency on legacy `X-User-Id` was found.

## Backend endpoint list

Found route groups: `/api/auth`, `/api/profiles`, `/api/privacy`, `/api/dashboard`, `/api/planner`, `/api/environment`, `/api/risk`, `/api/air`, `/api/alerts`, `/api/settings`, `/api/subscriptions`, `/api/symptoms`, `/api/recommendations`, `/api/notifications`, `/api/observability`, `/api/validation`, `/api/health`.

Status: DONE

## iOS endpoint list

`mobile/ios/HiAir/Networking/APIClient.swift` calls auth, environment, risk, dashboard, air, symptoms, planner, settings, notifications, and subscriptions endpoints.

Status: DONE

## Android endpoint list

`mobile/android/app/src/main/java/com/hiair/network/ApiClient.kt` calls auth, planner, dashboard, air, environment, risk, symptoms, settings, notifications, and subscriptions endpoints.

Status: DONE

## Auth headers

Both mobile clients use `Authorization: Bearer <token>`. Legacy `X-User-Id` appears only in backend tests/docs for migration context.

Status: DONE

## Risk enum compatibility

The backend includes compatibility handling for `medium`/`moderate`. Contract documentation exists in `docs/api-contract-risk-levels.md`.

Status: DONE

## Base URL config

- iOS: environment / Info.plist / default local fallback.
- Android: `BuildConfig.API_BASE_URL` split by debug/release.
- Backend scripts: local defaults for preflight.

Status: PARTIAL

Gap: Release builds still require environment/account proof that production/staging API URLs are reachable.

## Error response handling

Backend returns standard FastAPI error payloads. Mobile-specific UX handling needs manual QA.

Status: PARTIAL

## Observability endpoints

Mobile clients no longer call AI observability summary endpoints. `/api/observability/*` is documented as internal-only and remains ops-gated by `X-Admin-Token`.

Status: FIXED

Policy: `docs/api/MOBILE-OBSERVABILITY-ACCESS-POLICY.md`

## Push device token

- `POST /api/notifications/device-token` accepts JSON `platform`, `device_token`, optional `profile_id`.
- Auth: **Bearer JWT** via `get_current_user_id`. **No** notification admin token for this route.
- iOS/Android clients use the single path documented in `docs/notifications/PUSH-READINESS-STATUS.md`.

Status: DONE (Phase 18 verification)

## Fixes applied

- iOS Xcode project now includes the theme source required by screens using current UI components.
- Backend protected-env ops token behavior now fails closed.
- Android backup policy hardened.

## Remaining blockers

- FIXED: mobile observability endpoint access removed from user-facing clients.
- BLOCKED_BY_ENV: API contract smoke requires running backend and DB.
- NEEDS_MANUAL_QA: mobile error states and auth expiration handling.
