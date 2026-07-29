# iOS Connection Hardening Audit — TF 149 follow-up

**Date:** 2026-07-29  
**Branch:** `fix/ios-connection-hardening`  
**Base:** `origin/main` @ `3b9dde7` (includes PR #37)  
**Trigger:** Physical TF **149** — profile auto-create, location, HealthKit all failing on device.

## Device evidence (TF 149)

- UI: `profile.ensure.failed` («Проверьте соединение…»)
- Analytics: `profile_ensure_failed reason=unknown`
- Location recovery buttons absent (outcome ≠ `.needsLocation`)
- City chip could show locality while profile missing
- Production API ephemeral smoke: `GET/POST /api/profiles` **OK** with `adult` + valid coords
- Backend SHA unchanged during QA: `6c3f522…`

## Root causes fixed (client)

| ID | Defect | Fix |
|----|--------|-----|
| P0-1 | `reason=unknown` catch-all hid decode/TLS/cancel | Rich `ProfileEnsureMapper` (`decode`/`transport`/`cancelled`/`offline`) + analytics `error_type`/`http_status`/`url_code` |
| P0-2 | Location CTAs only on `.needsLocation` | `suggestsLocationRecovery` + show recovery on transport/server/unknown; CTA bootstraps location first |
| P0-3 | `applyAuthHeaders` preferred stale global token | Explicit caller `accessToken` always wins |
| P0-4 | Account switch kept prior coords/city | Clear lat/lon/source/place + ensure outcome on user change |
| P0-5 | Health consent 2xx + decode/bind mismatch → local not Connected | Persist consent after 2xx even on schema drift; rebound on account mismatch; reconcile from `/wearables/today` |
| P1-1 | `.notDetermined` immediately thrown as denied | Wait for authorization decision before failing |
| P1-2 | Auth sync required refresh token | Sync APIClient when userId+accessToken present |
| P1-3 | Invalid persona strings → API 422 → opaque fail | Normalize persona/sensitivity before create |
| P1-4 | list/create decode failures opaque | Map empty/non-JSON 2xx → `invalidResponse` → transport |

## Non-goals this PR

- No production backend deploy
- No TestFlight upload in this change set (next candidate after merge + Xcode Cloud)
- Physical QA not re-run here — blocked until build **>149**

## Verification

- Unit: `ProfileEnsureTests` (+ mapper/auth/location switch coverage)
- Local: `xcodebuild` HiAirTests

## Next version

After merge to `main`: Xcode Cloud Archive → TestFlight **>149** → resume physical matrix on new build only.
