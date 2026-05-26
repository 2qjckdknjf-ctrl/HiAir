# HiAir 100 Percent Closure Gaps

| ID | Severity | Area | Issue | Evidence | Fix | Status | Owner Action |
|---|---|---|---|---|---|---|---|
| GAP-001 | P0 | Risk Contract | Legacy risk engine returned `medium` as output level | `backend/app/services/risk_engine.py`, backend gate evidence | Canonicalized output to `moderate`; compatibility handled in `risk_level_contract` | DONE | None |
| GAP-002 | P0 | Planner Contract | Planner safe-window logic used `medium` output path | `backend/app/api/planner.py` | Updated safe window contract to `low/moderate` | DONE | None |
| GAP-003 | P0 | Historical Validation | Validation order expected `medium` | `backend/app/services/risk_validation_service.py` | Updated validation ranking/fixtures to `moderate` | DONE | None |
| GAP-004 | P1 | Store Handoff | `DATA_SAFETY.md` artifact missing from store packet | `docs/release/store/` before update | Added `docs/release/store/DATA_SAFETY.md` and checker coverage | DONE | None |
| GAP-005 | P1 | External Checker Scope | External checker did not verify screenshot/data-safety presence | `scripts/release/check_external_readiness.py` | Added checks for `DATA_SAFETY.md` and `SCREENSHOT_CHECKLIST.md` | DONE | None |
| GAP-006 | P1 | Real-device QA Evidence | No structured real-device QA matrix template | `docs/release/qa/` before update | Added `REAL_DEVICE_QA_REPORT.md` template with required columns/flows | DONE | Populate with real-device evidence |
| GAP-007 | P1 | External Credentials | Strict external readiness requires real Apple/Google/APNS/FCM/legal runtime values | `python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local` | Env template + strict checker implemented | MISSING | Provide real runtime values in local/runtime env; do not commit secrets |
| GAP-008 | P1 | Legal Finalization | Privacy Policy/Terms statuses are not finalized | `docs/06_PRIVACY_LEGAL_STATUS.md`, strict checker output | Added explicit status markers and blocker detection | BLOCKED | Legal owner sign-off and publish final URLs/status |
| GAP-009 | P1 | Public Launch Gate | Strict external gate fails while owner-only inputs are absent | `scripts/release/hiair_final_gate.sh --strict-external` | Gate is correct fail-fast behavior for launch closure | BLOCKED | Close GAP-007 and GAP-008, then rerun strict gate |
| GAP-010 | P1 | Privacy Regression Coverage | Delete-account endpoint lacked dedicated API regressions; export coverage did not assert refresh-token section | `backend/tests/test_privacy_delete_api.py`, `backend/tests/test_privacy_export_api.py` | Added delete endpoint regressions and extended export assertions (incl. `auth_refresh_tokens`) | DONE | None |
