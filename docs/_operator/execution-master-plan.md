# HiAir Execution Master Plan

Last updated: 2026-04-18  
Execution policy: no phase skipping, evidence-first closure

## Mission state

Drive HiAir from partial readiness to:
- Closed Beta Ready (truthful)
- Store Handoff Ready (truthful)
- Maximum practical Public Launch readiness (with explicit external blockers)

## Phase order (mandatory)

1. Phase 1 - Truth alignment  
2. Phase 2 - Critical stabilization  
3. Phase 3 - Core product completion  
4. Phase 4 - Release engineering hardening  
5. Phase 5 - Store/Beta readiness closure  
6. Phase 6 - Full ready state package

---

## Phase 1 - Truth alignment

### Objectives
- Align docs with actual code/runtime status.
- Define canonical documents and ownership.
- Freeze single source gap map and readiness baseline.

### Work items
1. Create canonical-truth matrix: doc claim -> code evidence -> status.
2. Update stale documents:
   - `README.md`
   - `docs/mvp-spec.md`
   - `docs/architecture.md`
   - `docs/task-backlog.md`
   - `docs/store-upload-last-mile.md`
3. Mark historical reports as time-bound evidence, not current truth.
4. Publish operator baseline in `docs/_operator/*`.

### Exit criteria
- No known contradiction between canonical docs and current implementation state.
- Every unresolved item mapped to a gap ID.

### Evidence
- Updated docs diff
- Cross-link validation pass
- Reviewed canonical-truth matrix

---

## Phase 2 - Critical stabilization

### Objectives
- Remove critical/high blockers to core trust and release safety.

### Priority fixes (strict)
1. GAP-001 auth fallback hardening (`X-User-Id` controls/deprecation).
2. GAP-002 JWT secret strictness (no insecure default in non-dev).
3. GAP-003 webhook signature strict enforcement.
4. GAP-004 historical validation script fail-fast behavior.
5. GAP-005 Android network manifest/policy hardening.
6. GAP-010 add pytest to CI; GAP-011 add mobile CI baselines.

### Exit criteria
- No open critical gaps.
- Core security paths verified by tests.
- CI cannot pass on known critical regressions.

### Evidence
- Security test results
- CI workflow run links/log extracts
- Updated gap statuses in `master-gap-report.md`

---

## Phase 3 - Core product completion

### Objectives
- Ensure all core user flows are complete and coherent across platforms.

### Scope
- onboarding
- profile management
- dashboard
- planner
- symptoms
- settings
- alerts
- subscriptions/paywall behavior
- privacy export/delete
- localization consistency (where planned)

### Work items
1. Unify auth/session and navigation behavior iOS/Android.
2. Remove hardcoded URLs and centralize env config by build type.
3. Resolve contract semantic drift (risk levels, legacy/new API blending).
4. Strengthen client-side error handling and empty-state UX.
5. Expand privacy data flow coverage and verify ownership checks end-to-end.

### Exit criteria
- Every core flow status: working (not partial/broken) with evidence.
- No P1 user-visible blockers in closed-beta paths.

### Evidence
- Updated QA run report
- API/mobile integration test evidence
- Flow-by-flow checklist completion

---

## Phase 4 - Release engineering hardening

### Objectives
- Make release process reproducible, testable, and auditable.

### Work items
1. Build reproducibility:
   - deterministic backend gate
   - deterministic mobile build commands
2. CI gates:
   - backend compile + pytest + smoke + historical validation
   - Android build/lint/tests
   - iOS build/analyze
3. Artifact quality:
   - manifest generation with relative paths + checksums
   - release evidence packet generation
4. QA matrices:
   - device/OS matrix and pass/fail results
5. Rollback and last-mile docs:
   - explicit hold/go/rollback steps
   - owner responsibilities and manual dependencies

### Exit criteria
- CI enforces all required gates.
- Release artifacts reproducible from clean workspace.
- QA matrix and rollback path documented and tested.

### Evidence
- CI pass logs
- Fresh manifest with checksums
- Updated runbooks/checklists

---

## Phase 5 - Store/Beta readiness closure

### Objectives
- Close all store/beta handoff requirements except explicit external approvals.

### Work items
1. Finalize store packet:
   - app metadata, screenshots, release notes
   - privacy label mapping
2. Resolve store quality blockers (icon/assets/runtime config).
3. Align legal drafts with real product behavior and obtain signoff track.
4. Produce exact upload and handoff instructions with owner checklist.

### Exit criteria
- Engineering side fully prepared for upload.
- Remaining blockers are external-only and explicitly listed.

### Evidence
- Store handoff checklist
- Finalized legal review status
- Upload rehearsal log

---

## Phase 6 - Full ready state package

### Objectives
- Produce final truth package for go/no-go decisions.

### Deliverables
1. Final audit report (post-fix).
2. Final gap closure report (open/closed with evidence).
3. Residual risk register.
4. Go/No-Go verdict split:
   - Closed beta readiness
   - Store handoff readiness
   - Public launch readiness
5. External blocker ledger with owners and ETA.

### Exit criteria
- No unresolved critical/high engineering blockers.
- Remaining blockers are external/compliance and explicitly accepted.

---

## Immediate execution queue (next)

1. **Phase 1 completion pass**: rewrite stale canonical docs and map every contradiction to gap IDs.
2. **Phase 2 kickoff**:
   - [done] patch `validate_risk_historical.py` fail-fast
   - [done] harden auth fallback default and webhook secret handling
   - [done] fix Android manifest/network policy baseline
   - [done] add pytest stage into backend CI
3. Re-run verification and update all operator docs after each substage.

## Current active focus

- Complete remaining Phase 1 truth alignment doc rewrites.
- Continue Phase 2 for unresolved critical/high gaps:
  - [done] strict JWT secret runtime policy for protected env
  - [done] production-safe Android/iOS base URL and transport baseline
  - mobile CI gate introduction
  - contract harmonization guardrails

## Next execution slice (in-progress)

1. [done] Add mobile CI entry points (Android build/lint, iOS build) into repository workflow strategy.
2. [done] Expand webhook/auth/security negative-path tests to lock in new policies.
3. Start explicit contract harmonization plan for risk-level semantics (`medium` vs `moderate`).
4. Advance privacy export/delete coverage verification against all user-linked tables.

Progress on item 3:
- Implemented compatibility bridge for `medium` and `moderate` in key backend/mobile paths.
- Added API-boundary normalization + alias telemetry.
- Added versioned alias policy controls (`compat|warn|enforce`) and migration headers on legacy endpoints.
- Remaining work: collect client migration evidence, then switch to `enforce` mode by release policy.

Progress on item 4:
- Expanded privacy export/delete repository logic for extended AI/risk/alerts tables.
- Added DB-backed residual-data assertions to `scripts/smoke_db_flow.py`.
- Local evidence captured: full smoke run on temporary Postgres now passes with residual-data assertions.
- Remaining work: capture remote CI run evidence that executes these DB assertions on postgres.
  - Status: remote CI evidence now captured on `cursor/bootstrap-ci-and-tooling` (backend workflow success after ordering fix).

Additional stabilization outcome:
- DB smoke surfaced and fixed bytes/str robustness defects in auth/subscriptions/privacy code paths.
- Ops endpoint access tightened with admin-token policy and preflight/smoke script support.
- Retention/ops closure advanced with retention matrix, JSON evidence output, and incident runbook.
- Store metadata completeness is now machine-gated via `check_store_metadata_packet.py` (unchecked items/placeholders fail strict ops mode).

Phase 6 packaging progress:
- Added external blocker ledger, residual risk register, and explicit go/no-go verdict artifact.

## Tracking protocol

For each substage:
1. Analyze
2. Change
3. Verify (command/test/build)
4. Document (`global-audit`, `master-gap-report`, `readiness-scorecard`, `execution-master-plan`)
5. Move to next item
