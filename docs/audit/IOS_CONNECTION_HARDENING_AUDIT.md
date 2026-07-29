# iOS Connection Hardening Audit — TF 149 follow-up

**Date:** 2026-07-29
**Branch:** `fix/ios-connection-hardening`
**Base:** `origin/main` @ `3b9dde7` (PR #37 / TF 149 client SHA)
**PR:** #38
**Trigger:** Physical TF **149** — `profile_ensure_failed reason=unknown` ×2, generic network UI, no location CTA.

## Device evidence (TF 149)

- UI: `profile.ensure.failed` («Проверьте соединение…»)
- Analytics: `profile_ensure_failed reason=unknown` (×2 ~300ms apart)
- Location recovery buttons absent
- City chip could show locality while coords/profile missing
- Production API ephemeral smoke: `GET/POST /api/profiles` **OK**
- Backend SHA unchanged during QA: `6c3f522…`

## Root cause (physical cold launch)

1. **Opaque taxonomy:** non-API / non-offline failures collapsed to `.unknown` → generic network copy.
2. **Double ensure:** `prepareSessionForDataFetch` ensured, then `DashboardView.task` → `reloadDashboard()` ensured again (sequential, not covered by concurrent single-flight).
3. **City ≠ location readiness:** cached place name did not imply valid coordinates for create.
4. **Location CTA too late / too broad:** CTAs only on exact `.needsLocation` on TF149; early hardening wrongly broadened CTA to transport/server — corrected to **location-only**.

## Fixes in this PR

| ID | Defect | Fix |
|----|--------|-----|
| P0-1 | `reason=unknown` hid decode/TLS/cancel/HTTP | Typed `phase` + `category` + `diagnostic_code`; mapper covers decode/transport/cancelled/offline/HTTP |
| P0-2 | Double cold-launch ensure | Dashboard reload after prepare uses `skipProfileEnsure: true`; concurrent single-flight retained |
| P0-3 | Location CTA on API errors | `suggestsLocationRecovery` **only** for `.needsLocation` |
| P0-4 | Create success + list lag → false failure | Recovery list after create failure |
| P0-5 | Cancellation as network error | `.cancelled` distinct message; no location CTA; no generic failed copy |
| P0-6 | Stale global auth header | Explicit caller `accessToken` wins |
| P0-7 | Account switch kept coords/city | Clear lat/lon/source/place + ensure outcome |
| P0-8 | Health consent inactive not cleared | `reconcileServerConsent(isActive:false)` clears durable consent |
| P1 | Persona/location/auth sync | Normalize persona; in-ensure location bootstrap; APIClient auth sync |

## Non-goals

- No production backend / Cloudflare deploy
- No App Store submission / Android billing
- Physical matrix resumes only on TestFlight **>149**

## Verification gate

- Fresh DerivedData + HiAirTests + ProfileEnsureTests + UI suite ×3
- Release `CODE_SIGNING_ALLOWED=NO`
- `git diff --check`; both `ios-build` SUCCESS; review threads resolved
- Bugbot/security High=0 Medium=0 **in PR scope** (client); out-of-diff backend findings not merge blockers

## Next

Merge → Xcode Cloud Archive on merge SHA → TF **>149** → assign «Первый» → targeted physical retest → then 20/20 matrix.
