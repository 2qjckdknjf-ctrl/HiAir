# HiAir Global Audit (Truth-Based)

Last updated: 2026-04-18
Operator mode: HARD EXECUTION OPERATOR

## Executive summary

HiAir is not in a greenfield state; it is an advanced MVP/beta candidate with substantial backend/mobile/release scaffolding already implemented.  
Core build viability is proven for backend compile, backend unit tests, Android debug build, and iOS simulator build, but readiness is blocked by security, contract consistency, CI false-green risk, and launch/compliance external dependencies.

Current truth assessment:
- Technical maturity: **partial**
- Product maturity: **partial**
- Release maturity: **partial**
- Closed beta readiness: **near-ready with blockers**
- Store handoff readiness: **partial, blocked by external and policy gaps**
- Public launch readiness: **not ready**

## Audit evidence snapshot (fresh verification)

Fresh checks executed on 2026-04-18:
- `python3 -m compileall backend/app backend/scripts` -> pass
- `cd backend && ../.venv/bin/python -m pytest tests -q` -> `14 passed`
- `cd mobile/android && ./gradlew tasks --all` -> pass
- `cd mobile/android && ./gradlew assembleDebug` -> pass
- `cd mobile/ios && xcodebuild -list -project HiAir.xcodeproj` -> pass
- `cd mobile/ios && xcodebuild ... -sdk iphonesimulator ... build CODE_SIGNING_ALLOWED=NO` -> `BUILD SUCCEEDED`
- `../.venv/bin/python backend/scripts/check_env_security.py --strict` -> fail in strict mode without required envs (expected for unmanaged local env)
- `cd backend && DATABASE_URL=... ../.venv/bin/python scripts/init_db.py` -> fail (`connection refused`) due missing local Postgres runtime
- `docker --version` -> command not found (local runtime blocker for DB-backed smoke path)

## What exists (fact, not claims)

### Repository and structure
- Root has `backend`, `mobile`, `docs`, `.github/workflows`, `.tools`, `docker-compose.yml`.
- Backend includes FastAPI app, SQL migrations, scripts, tests.
- Mobile includes Android Gradle project and iOS Xcode project/XcodeGen spec.
- Docs include roadmap/spec/architecture/checklists/runbooks/release evidence/legal drafts.

### Backend surface
- Active routers include auth, profiles, privacy, dashboard, planner, environment, risk, air, alerts, settings, subscriptions, symptoms, recommendations, notifications, observability, thresholds, validation.
- Security, retention, smoke, and historical validation scripts exist.

### Mobile surface
- iOS app compiles for simulator.
- Android app builds debug APK.
- Main flows exist in code: onboarding/auth, dashboard, planner, symptom log, settings/subscriptions.

### QA and release assets
- QA run reports and beta cycle reports exist.
- Artifact manifest generation script exists.
- Release package and store upload docs exist.

## What is broken (verified or code-proven)

1. **Critical auth weakness:** fallback authentication via `X-User-Id` still grants access without bearer token.
2. **Critical secret default:** JWT secret has insecure default (`dev-only-change-me`) if env not set.
3. **Critical webhook trust gap:** subscription webhook signature verification returns true when secret is absent.
4. **CI false-green risk:** `validate_risk_historical.py` never exits non-zero on failed validation, while CI relies on it.
5. **Android networking blocker:** `AndroidManifest.xml` lacks explicit `INTERNET` permission and has no cleartext/network-security policy while app uses `http://10.0.2.2:8000`.
6. **Data privacy mismatch risk:** privacy export/delete flow does not convincingly cover all expanded AI/alerts data surfaces end-to-end.

## What is partial

- Auth model migration: bearer auth exists, but legacy compatibility path remains.
- Product flows: present but uneven across platforms (iOS auth-gated shell vs Android tab-first flow).
- Risk domain: dual legacy/new stacks (`/risk` and `/air`) coexist with potential semantic drift (`medium` vs `moderate`).
- Release evidence: artifacts/checklists exist, but evidence reproducibility is machine/path-dependent.
- CI: backend workflow exists, but no mobile gates and no pytest stage in CI pipeline.
- Legal/compliance: policy drafts and review docs exist, but still draft-level.

## What is missing

- Canonical single source of truth document set and status governance.
- Mobile CI (Android lint/tests/build, iOS build/analyze) as required release gates.
- Automated integration verification of backend + DB in a reproducible local/CI path independent of developer machine state.
- Complete contract conformance checks for mobile/backend schema evolution.
- Finalized legal text + controller contact and formal legal signoff.
- Store metadata readiness packet (final screenshots/listings/privacy mapping by platform form fields).

## Contradictions between docs and reality

1. `docs/mvp-spec.md` marks premium subscription as out-of-MVP; code and QA/docs already include subscription flows and webhook processing.
2. `docs/architecture.md` reflects earlier simplified model; actual backend includes broader router/domain surface and AI/observability paths.
3. `README.md` "start now from docs/bootstrap" positioning is stale relative to current implemented system and reports.
4. `docs/task-backlog.md` has parent item "Утвердить стек" unchecked while all child stack decisions are checked.
5. `docs/store-upload-last-mile.md` references `qa-run-002-report.md` for post-upload reporting despite later reports existing.
6. `docs/mobile-audit-2026-04-07.md` claims lint/icon fixes; current Android manifest uses system icon and lacks network permission declaration.

## Critical blockers (must-fix before truthful readiness claim)

- Auth fallback hardening (`X-User-Id` deprecation path).
- Webhook secret enforcement and signature policy hard fail.
- Android network manifest policy + runtime base URL env strategy.
- CI gate correctness (historical validation fail-fast, pytest in CI, mobile build gates).
- Privacy flow completeness alignment (export/delete vs actual data model).

## Release blockers

- No mobile CI enforcement.
- Local DB-backed smoke not reproducible on this machine without Docker/Postgres.
- Store pipeline depends on manual account access (Apple/Google).
- Release artifact proof uses absolute local paths, not portable evidence.

## Security/privacy blockers

- Weak fallback auth header path.
- Unsafe default JWT secret behavior if env missing.
- Webhook signature permissive behavior when secret absent.
- Public observability/provider health exposure needs explicit policy and potentially access control.
- Privacy/legal drafts not fully aligned to final operational behavior guarantees.

## Tech debt that blocks readiness

- Dual risk engines and dual API semantics.
- Mobile hardcoded localhost base URLs in multiple screens/view models.
- Documentation drift across roadmap/spec/architecture/release docs.
- Build artifacts and tooling bloat in repo surface increase audit noise and operational risk.

## Canonical truth proposal (for Phase 1)

Until rewritten:
- Product scope truth: `docs/mvp-spec.md` + `docs/task-backlog.md` + audited code state.
- Technical truth: backend/mobile code and executed checks.
- Release truth: fresh run outputs and current artifact generation, not historical reports alone.
- Legal truth: drafts are non-final and must be explicitly treated as blockers.

## Truth-based project stage assessment

HiAir is in **late MVP / pre-beta hardening** stage, not release-final.  
It can progress to **Closed Beta Ready** after critical security/contract/CI fixes and truth alignment.  
It is **not store-ready** and **not public-launch-ready** until mobile/release/compliance hardening and external blockers are closed.

## Progress update (Phase 2 kickoff, 2026-04-18)

Executed and verified:
- Fixed CI false-green risk: `validate_risk_historical.py` now exits non-zero on failed validation.
- Added pytest execution into backend CI workflow.
- Added Android `INTERNET` permission and explicit cleartext traffic allowance for current HTTP dev flow.
- Disabled legacy header auth by default via `ALLOW_LEGACY_USER_HEADER_AUTH=false` setting.
- Hardened subscription webhook endpoint: now requires configured webhook secret.

Post-change checks:
- backend compile -> pass
- backend pytest -> `14 passed`
- historical validation -> pass
- Android `assembleDebug` -> pass

Phase 1 truth-alignment updates applied:
- `docs/store-upload-last-mile.md` updated to avoid stale fixed QA report reference.
- `docs/task-backlog.md` stack approval parent status aligned with child statuses.
- `docs/mvp-spec.md` clarified subscription scope (technical beta scaffolding vs monetization scope).
- `README.md` start-section aligned with current phase-based execution reality.
- `docs/architecture.md` augmented with implemented module surface and operator truth-source pointer.

Additional stabilization batch completed:
- Backend runtime guardrails:
  - protected env now rejects insecure JWT default
  - protected env now rejects legacy header-auth enablement
- Mobile API base URL now centralized:
  - Android via `BuildConfig.API_BASE_URL` (debug/release split)
  - iOS via `API_BASE_URL` Info key and optional `HIAIR_API_BASE_URL` override
- Android release/debug network policy split:
  - debug cleartext enabled
  - release cleartext disabled via manifest placeholder
- Client-side legacy header fallback removed in API clients (bearer token only).
- Added mobile CI workflows:
  - `.github/workflows/android-ci.yml`
  - `.github/workflows/ios-ci.yml`
- Added backend security regression tests:
  - `backend/tests/test_security_runtime_policies.py`
- Added risk-level compatibility hardening:
  - backend model accepts both `moderate` and `medium` for air-domain risk inputs
  - alert/recommendation logic handles both values consistently
  - iOS dashboard color mapping now handles both values
- Privacy repository coverage expanded:
  - export now includes AI/risk/alerts extended tables and expanded profile/settings fields
  - delete flow now explicitly removes profile-linked `ai_explanation_events` before user cascade delete
- DB-backed deletion verification embedded into smoke flow:
  - `backend/scripts/smoke_db_flow.py` now asserts zero residual personal rows across core/AI/alerts tables after account deletion.
- Contract documentation added:
  - `docs/api-contract-risk-levels.md` formalizes current `medium`/`moderate` compatibility bridge and deprecation direction.

Extra verification:
- Android `assembleRelease` -> pass
- iOS simulator build -> pass
- backend pytest -> `18 passed` (including security and risk-compatibility tests)
- Runtime security probes:
  - staging + insecure JWT -> startup fail (expected)
  - staging + legacy header auth enabled -> startup fail (expected)
  - development + default settings -> startup pass

Environment/tooling blockers observed:
- `xcodegen` command unavailable on this machine (external local tooling dependency); existing `HiAir.xcodeproj` build used for verification.

## Additional evidence run (local Postgres e2e smoke, 2026-04-18)

Temporary local Postgres was initialized and used for full backend smoke execution.

During the run, three real data-type defects were discovered and fixed:
- `verify_password` failed when DB returned `password_hash` as bytes.
  - fix: bytes decode support in `app/services/security.py`
  - test: `backend/tests/test_security_password_hashing.py`
- subscription responses failed when `status/plan_id` came back as bytes.
  - fix: normalization helper in `app/services/subscription_repository.py`
  - test: `backend/tests/test_subscription_repository.py`
- privacy export failed on `provider_subscription_id` type mismatch (`text = bytea`) and bytes serialization.
  - fix: text normalization and bytes-safe row serialization in `app/services/privacy_repository.py`
  - test: `backend/tests/test_privacy_repository_serialization.py`

After fixes:
- backend tests: `24 passed`
- full `scripts/smoke_db_flow.py` against local Postgres: pass
- privacy export + delete-account + residual-row assertions: pass
- Android store-quality fix:
  - replaced system placeholder icon with app-owned launcher icon (`ic_hiair_launcher.xml`)
  - revalidated via `assembleDebug` + `lintDebug`: pass
- Ops endpoint hardening:
  - protected `notifications` health endpoints and `observability` endpoints with admin token gate when `NOTIFICATION_ADMIN_TOKEN` is configured.
  - updated `smoke_db_flow.py` and `beta_preflight.py` to pass `X-Admin-Token` in protected mode.
- Legal-draft truth alignment:
  - `privacy-policy-draft.md` expanded to reflect AI/alerts data surfaces and admin-token protected observability behavior.
  - `terms-of-service-draft.md` clarified beta subscription technical-validation scope and admin authorization boundaries.
- Interim closure package added:
  - `docs/_operator/current-readiness-closure.md`
- Ops evidence hardening:
  - Added `docs/data-retention-matrix.md` to map table-level retention/delete coverage.
  - Enhanced `backend/scripts/retention_cleanup.py` with `--json-output` for portable audit artifacts.
  - Added `docs/incident-response-runbook.md` and linked it in ops handover checklist.
- Contract hardening progress:
  - Added API-boundary normalization for `medium`/`moderate` aliases in legacy and air API families.
  - Added alias telemetry in observability metrics (`risk_level_alias_counts`).
- Store handoff preparation:
  - Added `docs/store-metadata-packet.md` with draft app copy, screenshot matrix, privacy label mapping, and reviewer-note template.
- Remote CI evidence captured on branch `cursor/bootstrap-ci-and-tooling`:
  - Android CI success: run `24615985042`
  - iOS CI success: run `24616042251`
  - Backend CI success (after workflow ordering fix): run `24616100932`
