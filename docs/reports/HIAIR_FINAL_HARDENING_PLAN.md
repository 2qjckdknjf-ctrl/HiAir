# HiAir Final Hardening Plan

## 1. Project Map
- Backend stack: FastAPI, Psycopg/PostgreSQL, pytest, scripts under `backend/scripts`, SQL migrations under `backend/sql`.
- iOS stack: SwiftUI app in `mobile/ios`, Xcode project `HiAir.xcodeproj`, URLSession networking, local session persistence.
- Android stack: Kotlin app in `mobile/android`, Gradle build, custom HTTP client, local shared prefs session storage.
- CI/CD: GitHub workflows under `.github/workflows` (to validate and strengthen during audit).
- Docs: core docs under `docs`, operator artifacts under `docs/_operator`, release/QA docs.
- Scripts: backend gates and release helpers in `backend/scripts`; repo-level release gate script to be added under `scripts/release`.
- Migrations: SQL files in `backend/sql` applied lexicographically.
- Env/config: `.env` patterns in backend docs/scripts; mobile base URLs from Info.plist/BuildConfig/runtime config.
- Store/release materials: existing docs in `docs/release-*` and `docs/store-*`; target handoff packet under `docs/release/store`.

## 2. Readiness Matrix (Initial Baseline)
- Backend: PARTIAL
- Security: PARTIAL
- Auth: PARTIAL
- Privacy/GDPR: PARTIAL
- AI/risk engine: PARTIAL
- Alerts/notifications: PARTIAL
- iOS: PARTIAL
- Android: PARTIAL
- CI: PARTIAL
- Tests: PARTIAL
- Store readiness: MISSING
- Docs: PARTIAL
- Closed beta readiness: PARTIAL
- Public launch readiness: MISSING

## 3. P0 / P1 / P2

### P0 (Release / Security / Beta blockers)
- Enforce secure auth fallback behavior and remove insecure legacy paths in protected envs.
- Verify refresh/logout flow and session invalidation behavior across iOS and Android.
- Ensure webhook/admin/observability access control behavior is enforced and regression-tested.
- Ensure release network config safety (HTTPS-only for release, no cleartext production leakage).
- Add final multi-platform release gate and execute with evidence.

### P1 (Should close for closed beta)
- Normalize API/mobile parity docs and response/error handling.
- Expand privacy export/delete verification and evidence.
- Tighten CI workflow coverage for backend + mobile gates.
- Finish store/legal/beta handoff docs with explicit external blockers.

### P2 (Non-blocking backlog)
- Residual UX polish and accessibility enhancements not blocking beta.
- Additional analytics/ops niceties beyond current release gate scope.

## 4. Execution Order
1. Audit repository and baseline branch/state capture.
2. Baseline checks (backend, iOS, Android, CI config scan).
3. Security hardening pass (auth/JWT/webhooks/admin/secrets/CORS/transport/cleartext).
4. Backend hardening pass (API consistency, risk/alerts/briefing/insights/privacy/DB).
5. iOS hardening pass (auth/session/network/release config/localization/safety strings).
6. Android hardening pass (auth/session/network/release config/localization/safety strings).
7. Mobile/API parity matrix generation and mismatch fixes.
8. CI/CD hardening + `scripts/release/hiair_final_gate.sh`.
9. Store/legal/beta handoff package creation/update.
10. Canonical docs truth pack refresh.
11. Final checks, commits, pushes, final report completion.
