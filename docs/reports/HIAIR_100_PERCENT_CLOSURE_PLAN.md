# HiAir 100 Percent Closure Plan

## 1. Repository Map
- Backend: `backend/` (FastAPI, SQL migrations, tests, release/security scripts).
- iOS: `mobile/ios/` (SwiftUI app, networking/session/auth).
- Android: `mobile/android/` (Kotlin app, Gradle, networking/session/auth).
- Docs: `docs/` + `docs/release/` + `docs/release/store/` + `docs/reports/`.
- CI: `.github/workflows/` (`backend-ci.yml`, `ios-ci.yml`, `android-ci.yml`, `external-blocker-ops.yml`).
- Scripts: `scripts/release/`, backend scripts under `backend/scripts/`.

## 2. Current Readiness Matrix
- Engineering core: near-complete baseline from previous hardening branch.
- External strict readiness: expected non-green until owner-provided credentials/legal/device evidence is complete.
- Immediate objective: convert all unresolved items into either `DONE` (if codable) or precise `BLOCKED` with owner action.

## 3. P0/P1/P2 Backlog
- `P0`: any failing engineering gates, auth/security regressions, release misconfigurations, secret leaks.
- `P1`: contract drifts, docs drift, missing QA/launch evidence templates, incomplete external checker logic.
- `P2`: non-blocking clarity/documentation polish.

## 4. Engineering Closure Plan
1. Run baseline repo/state checks and capture evidence.
2. Run repo-wide audit scan for risk markers.
3. Fix all codable gaps found in backend/mobile/scripts/docs.
4. Re-run all engineering gates until green.

## 5. Backend Closure Plan
1. Validate auth ownership/risk-level contract output.
2. Re-run backend tests, gate, and security checks.
3. Ensure compatibility mappings are boundary-only and tested.

## 6. Security Closure Plan
1. Re-check auth, webhook, admin, and env-policy protections.
2. Run secret baseline scan path in final gate.
3. Verify iOS/Android release transport safety checks.

## 7. Privacy/GDPR Closure Plan
1. Verify export/delete flows remain surfaced in both mobile clients.
2. Ensure privacy/legal status docs include explicit status markers.
3. Keep external-only dependencies listed as `BLOCKED`.

## 8. AI/Risk Closure Plan
1. Reconfirm deterministic risk core and explanation-only AI behavior from existing tests/docs.
2. Verify canonical risk output levels and compatibility handling.

## 9. iOS Closure Plan
1. Build debug + release(no-sign).
2. Verify auth/session/refresh and privacy action coverage docs.
3. Confirm release HTTPS guard remains enforced.

## 10. Android Closure Plan
1. Run test/lint/assemble debug+release.
2. Verify release HTTPS + cleartext disabled checks.
3. Confirm privacy actions and localization docs remain aligned.

## 11. CI/CD Closure Plan
1. Validate workflow coverage.
2. Validate `scripts/release/hiair_final_gate.sh`.
3. Keep strict external mode failing only on true owner blockers.

## 12. Store/Legal Handoff Closure Plan
1. Ensure required store/legal docs exist and are synchronized.
2. Ensure Data Safety artifact presence.
3. Keep explicit legal finalization statuses.

## 13. External 100% Checklist Closure Plan
1. Keep `docs/release/EXTERNAL_100_CHECKLIST.md` authoritative.
2. Keep `backend/.env.external.example` complete and secret-free.
3. Strengthen `scripts/release/check_external_readiness.py` validations and status vocabulary.

## 14. Final Verification Plan
1. Backend tests/gate.
2. iOS build checks.
3. Android test/lint/build checks.
4. Final gate non-strict.
5. External check non-strict and strict.
6. Final gate strict external.

## 15. Definition of Done
- All engineering gates pass.
- All codable P0/P1 items are `DONE`.
- Remaining unresolved items are only external and recorded as `BLOCKED` with exact owner action and verify commands.
- Final report, livelog, and gap ledger are fully evidence-backed.
- Public launch is not marked 100% unless strict external checks pass.
