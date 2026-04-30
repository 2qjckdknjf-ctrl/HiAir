# HiAir Master Gap Report

Last updated: 2026-04-18

## Gap list

| ID | Area | Description | Impact | Severity | User-visible | Release-blocking | Fix strategy | Verification method |
|---|---|---|---|---|---|---|---|---|
| GAP-001 | Security/Auth | `X-User-Id` header can authenticate without bearer token | Account takeover risk if user id leaks/guessed | critical | no | yes | Deprecate and disable fallback in production mode; keep explicit temporary migration flag only | API tests: protected endpoints reject missing/invalid bearer; migration flag tests |
| GAP-002 | Security/Secrets | JWT secret has insecure default fallback | Token forgery risk under bad env config | critical | no | yes | Remove default in strict runtime; fail startup if missing in non-dev | Startup config validation test + strict env check in CI |
| GAP-003 | Security/Webhooks | Subscription webhook verifies true when secret absent | Subscription tampering risk | critical | no | yes | Require secret for non-local mode; reject unsigned payloads | Unit tests for signature enforcement + webhook negative tests |
| GAP-004 | CI Integrity | `validate_risk_historical.py` does not fail process on failed cases | False-green CI and regression leakage | critical | no | yes | Return non-zero exit when validation fails | Intentional failing fixture case in CI |
| GAP-005 | Android Networking | Manifest missing explicit internet permission and cleartext policy while app targets HTTP local backend | Core flow network failure on device/emulator | critical | yes | yes | Add permission and explicit debug network policy; migrate release to HTTPS base URL | Android instrumentation/manual smoke with real API endpoint |
| GAP-006 | Mobile Config | Hardcoded localhost base URLs across iOS/Android screens/VMs | Non-portable builds, store invalid runtime config | high | yes | yes | Centralize base URL config by build type/env; remove literals | Unit checks + grep guard + runtime config smoke |
| GAP-007 | Contract Consistency | Coexisting legacy `/risk` and new `/air` flows with different level semantics (`medium` vs `moderate`) | Inconsistent recommendations/alerts/UI behavior | high | yes | yes | Define canonical risk enum contract and add translation layer/deprecation path | Contract tests + mobile snapshot assertions |
| GAP-008 | Privacy/Data | Export/delete appears incomplete against expanded AI/alerts schema | Compliance and trust risk | high | yes | yes | Expand privacy repositories for all user-linked data tables and retention semantics | Privacy integration test: export coverage + delete verification queries |
| GAP-009 | Observability Access | Metrics/provider-health endpoints exposed without auth policy | Operational data leakage | high | no | yes | Introduce scoped auth or restrict to internal environment | Endpoint auth tests + staging access checks |
| GAP-010 | CI Coverage | Backend CI does not run pytest suite | Regressions bypass CI | high | no | yes | Add pytest stage with deterministic env | CI green with pytest and failure on injected regression |
| GAP-011 | Mobile CI | No Android/iOS build gates in CI | Mobile regressions reach release candidates | high | no | yes | Add Android build/lint/tests and iOS build/analyze gates | CI pipeline evidence on PR |
| GAP-012 | Build Repro | DB smoke depends on local Postgres runtime not available by default (`docker` absent on machine) | Incomplete local readiness validation | medium | no | no | Provide deterministic local bootstrap doc/alt path (devcontainer, local PG instructions) | Fresh-machine bootstrap test |
| GAP-013 | Docs Truth Drift | README/spec/architecture/backlog/release docs contradict current implementation | Wrong decisions and false status claims | high | yes | yes | Phase-1 truth alignment and canonical doc ownership | Doc review checklist + cross-link integrity check |
| GAP-014 | Mobile Product Flow | iOS requires auth/session before tabs, Android starts tabs-first and login in settings | Cross-platform UX and auth behavior mismatch | medium | yes | no | Unify entry flow and auth propagation behavior | Manual QA checklist for both platforms |
| GAP-015 | API Error Handling | Android client often does not enforce strict HTTP status handling | Silent failures and poor diagnostics | medium | yes | no | Normalize network layer error contract and handling policy | Unit tests for 4xx/5xx parsing paths |
| GAP-016 | Release Evidence Portability | Artifact manifest uses absolute machine-specific paths | Weak reproducibility and audit portability | medium | no | no | Emit relative paths and environment metadata | Regenerate manifest on clean path and compare |
| GAP-017 | Store Quality | Android app icon uses system default placeholder | Store rejection/poor quality signal | medium | yes | yes | Add production icon assets and manifest references | Lint + Play pre-check + manual review |
| GAP-018 | Legal Finalization | Privacy/ToS drafts still placeholders for controller contact/jurisdiction | Legal and store compliance blocker | high | yes | yes | Finalize with legal counsel and align in-app/store text | Signed legal review checklist |
| GAP-019 | Data Retention Ops | Retention coverage and policy mapping not fully proven for all operational/AI tables | Data governance drift | medium | no | no | Audit table-by-table retention matrix + update cleanup scripts | Retention dry-run report with table coverage |
| GAP-020 | Repo Hygiene | Large vendored tools/build artifacts increase noise and risk accidental inclusion | Operational friction, larger diffs | low | no | no | Clarify tooling policy, tighten `.gitignore`, separate generated outputs | Clean status checks after build |
| GAP-021 | Store Metadata Packet | No complete final listing packet evidence (screenshots, text, privacy labels mapped) | Store handoff incompleteness | high | yes | yes | Produce platform-specific metadata checklist package | Signed handoff checklist with asset links |
| GAP-022 | External Access | Apple/Google console credentials not in engineering control | Blocks final upload and tester distribution | high | no | yes | Track as external blocker with owner/date SLA | Owner confirmation and console upload evidence |

## Current prioritization

Priority order (strict):
1. GAP-001, GAP-002, GAP-003, GAP-004, GAP-005
2. GAP-006, GAP-007, GAP-008, GAP-009, GAP-010, GAP-011
3. GAP-013, GAP-018, GAP-021, GAP-022
4. Remaining medium/low debt and hygiene gaps

## Progress snapshot (2026-04-18, after Phase 2 kickoff)

- Partially addressed:
  - GAP-001: legacy header auth now default-off via config gate (`ALLOW_LEGACY_USER_HEADER_AUTH`).
  - GAP-003: webhook endpoint now hard-fails when webhook secret is missing.
  - GAP-004: historical validation script now exits non-zero on failed validation.
  - GAP-005: Android manifest now includes `INTERNET` and explicit cleartext allowance.
  - GAP-010: pytest added to backend CI workflow.
- Remaining for full closure:
  - GAP-001 requires full deprecation/removal plan and migration evidence.
  - GAP-003 requires test coverage for negative signature paths.
  - GAP-005 requires final production endpoint rollout evidence and cleartext-off release verification in distribution pipeline.
  - GAP-010 requires CI run evidence on remote pipeline.
  - GAP-011 and other high gaps remain open.

Second stabilization update:
- GAP-002: materially improved (protected env startup now rejects insecure JWT defaults).
- GAP-005: materially improved (Android debug/release cleartext split + centralized base URL config).
- GAP-006: materially improved (hardcoded mobile URLs removed from screen/viewmodel code paths).
- GAP-001: further improved (clients no longer send legacy `X-User-Id` fallback).
- GAP-011: materially improved (mobile CI workflow files added for Android and iOS paths).
- GAP-003/GAP-001: improved with added backend security regression tests.
- GAP-007: materially improved (risk-level compatibility bridge implemented and documented in `docs/api-contract-risk-levels.md`), canonical long-term deprecation still open.
- GAP-008: materially improved (privacy export/delete coverage expanded and DB-backed residual-data assertions added to smoke flow), remote CI execution evidence still pending.
- New robustness defects found and fixed via local DB run:
  - bytes/string decoding in auth password verification
  - bytes/string normalization in subscription repository response mapping
  - bytes-safe normalization in privacy export pipeline
- GAP-017: improved (Android launcher icon placeholder replaced with project icon asset; debug build + lint revalidated).
- GAP-009: materially improved (observability/provider health endpoints now admin-token gated in protected mode).
- GAP-019: materially improved (table-by-table retention matrix documented and retention script now supports JSON evidence output).
- Ops depth: improved (incident response runbook published and linked from ops handover checklist).
- GAP-007: further improved (API-boundary normalization and alias telemetry implemented; deprecation execution now reduced to versioning/removal phase).
- GAP-021: improved (store metadata packet draft created with screenshot/privacy-label/reviewer-note checklist).
- GAP-010: closed for current branch evidence scope (backend workflow now passes with compile/tests/prechecks/init/smoke/historical validation sequence).
- GAP-011: closed for current branch evidence scope (Android CI success and iOS CI success captured on remote runs).
- GAP-007: further improved (API-boundary normalization and alias telemetry implemented; deprecation execution now reduced to versioning/removal phase).

## Cycle: Aurora Calm v2 + Insights (2026-05-01 → ongoing)
### Cycle invariants (non-regression for new code)
- **GAP-006 (mobile hardcoded URLs)**: new screens MUST use `BuildConfig.API_BASE_URL`
  (Android) and `Info.plist API_BASE_URL` (iOS). PRs introducing hardcoded URLs
  in screen/viewmodel code are rejected.
- **GAP-007 (risk-level alias)**: new endpoints (`/api/insights/*`,
  `/api/briefings/*`) return canonical `low/moderate/high/very_high` only.
  Legacy `medium` is not produced by new code.
- **GAP-014 (mobile flow asymmetry)**: new screens (Insights tab, Briefing
  settings) implement identical auth/session/navigation behavior on iOS and
  Android. Cross-platform parity is verified before stage exit.
### New surfaces tracked
| Item                              | Owner   | Status   |
|-----------------------------------|---------|----------|
| Personal correlations table       | backend | in_progress |
| Insights API + AI explanation     | backend | in_progress |
| Insights tab UI (iOS + Android)   | mobile  | in_progress |
| Briefing schedule table           | backend | in_progress |
| Briefing dispatch worker          | backend | partial |
| Briefing settings UI              | mobile  | in_progress |
| Aurora Calm v2 design tokens      | mobile  | done |
| Atmospheric layer + globe         | mobile  | done |
| Privacy export coverage extension | backend | in_progress |
### Cycle exit will close
- Documentation drift: design system now has a code-level SoT and on-platform
  tokens, removing the "no canonical design tokens" gap.
- New surfaces enter privacy export and retention matrix from day one (no debt).
### Cycle exit explicitly does NOT close
- GAP-001 (legacy header auth removal in production rollout)
- GAP-005 (final cleartext-off release verification)
- GAP-013 (older docs full alignment beyond the new cycle's surfaces)
- Store handoff readiness
- Public launch readiness
