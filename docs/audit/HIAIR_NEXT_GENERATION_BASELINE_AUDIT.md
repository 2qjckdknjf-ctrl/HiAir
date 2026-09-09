# HiAir Next-Generation Baseline Audit

**Status:** IN_PROGRESS — PHASE 0 BACKEND SLICE VERIFIED / MOBILE ACTION SLICE IN_PROGRESS  
**Branch:** `codex/hiair-nextgen-phase0-action`  
**Upstream:** `feat/hiair-1.2-best-time-planner`  
**Purpose:** establish real source-of-truth before implementing the revised HiAir 1.2–1.6 roadmap.

## 1. Repository governance — current evidence

- GitHub repository: `2qjckdknjf-ctrl/HiAir`.
- GitHub default branch is currently `cursor/bootstrap-ci-and-tooling`, not `main`.
- `main` currently points to `23eeea664d210dc7f539f2a301dc54042d64e02f`.
- `main` is currently reported as unprotected.
- Active documented upgrade stack is `feat/hiair-1.2-best-time-planner`.
- Comparison `main...feat/hiair-1.2-best-time-planner` is diverged: upgrade branch 22 commits ahead / 110 behind `main`, merge base `537090b335f40cdad4a1526e469067a24b112add` at audit start.

### Governance finding

**P0/P1 source-of-truth risk:** release/product code and repository governance have drifted. Do not change the GitHub default branch or merge the upgrade stack directly into `main` until production release provenance is mapped and branch history is explicitly reconciled.

---

## 2. Existing HiAir 1.2 backend — verified

The existing activity planner is real and substantial. It is being hardened rather than replaced.

### Existing API

- `GET /api/planner/activities`
- `POST /api/planner/activity-plan`

`POST /activity-plan`:

- authenticates the user;
- enforces the existing `extended_forecast` entitlement;
- resolves a user-owned profile;
- optionally resolves a user-owned saved place;
- loads environment for that location;
- loads real forecast or returns an honest unavailable state;
- overlays forecast current data;
- builds Personal Load input from wearables;
- calls deterministic `activity_plan_engine.build_activity_plan()`;
- returns forecast provenance/freshness/quality/missing metrics.

No LLM participates in Action scoring.

### Existing public vocabulary

Activities:

- running
- walking
- cycling
- hiking
- dog_walk
- playground
- outdoor_sport
- beach
- outdoor_work
- ventilation

Intensity:

- low
- moderate
- high

Window tiers:

- best
- acceptable
- avoid

### Compatibility decision

Do not rename these public enums simply to match newer roadmap vocabulary. Any future semantic expansion must remain backward-compatible.

---

## 3. Existing deterministic Action Engine — verified strengths

- deterministic scoring;
- real hourly forecast inputs;
- honest `forecastAvailable=false` when forecast points are missing;
- air-unknown cases are not promoted to safe;
- Personal Load can affect high-intensity recommendations;
- child/playground caution;
- outdoor-worker adjustment;
- beach UV handling;
- ventilation uses a separate scoring path;
- structured reason codes;
- window confidence;
- source/freshness/quality/missing-metric propagation.

---

## 4. HiAir 1.2 Action gaps and status

### GAP A — `recommendedStart` was first-valid, not best-ranked

**Status: RESOLVED IN WORKING BRANCH.**

Old behavior scanned chronologically and returned the first duration-valid BEST/ACCEPTABLE chunk.

Implemented deterministic ranking now uses:

1. BEST over ACCEPTABLE;
2. higher aggregate decision score;
3. higher minimum candidate confidence;
4. earlier start only as the final stable tie-break.

Public response contract remains unchanged (`recommendedStart`).

Regression coverage added:

- later stronger BEST candidate beats earlier weaker BEST candidate;
- equal candidates keep earlier time as deterministic tie-break.

### GAP B — duration resolution is hourly/coarse

`ceil(duration_minutes / 60)` is used to determine forecast points required.

**Status: OPEN — P1.**

This is conservative but coarse for 15/30/45/90-minute actions. Do not fabricate sub-hour environmental precision. A later slice should evaluate weighted partial-hour scoring only when supported by provider/time-grid semantics.

### GAP C — merged-window confidence is not a conservative aggregate

Current window confidence is derived from a single environment point rather than the whole merged interval.

**Status: OPEN — P1.**

### GAP D — Action lifecycle is not a first-class persisted domain entity

No `planId` / accept / dismiss / complete lifecycle exists. Mobile currently records user actions through Protected Day events.

**Status: OPEN — P1/P2.**

Do not introduce persistence solely for architecture purity; add it when calendar/replanning/learning requires a durable plan identity.

### GAP E — Action weighting does not yet consume the full canonical multi-hazard layer

Core scoring is still centered on heat + air risk, Personal Load and limited activity-specific adjustments.

**Status: OPEN — P1.**

Integrate only canonical existing hazard outputs; do not create a duplicate hazard engine.

### GAP F — Action plan endpoint is Premium-gated

`POST /api/planner/activity-plan` currently uses `extended_forecast` entitlement.

**Status: PRODUCT DECISION REQUIRED.**

The revised product strategy favors keeping core safety guidance free and monetizing deeper planning/personalization. Do not alter store entitlement behavior until monetization/release implications are explicitly reconciled.

---

## 5. Baseline regressions discovered by real CI and fixed

Opening PR #75 exposed pre-existing upgrade-stack regressions. They were fixed before continuing feature work.

### Environment cache migration compatibility

A fresh legacy cache row could short-circuit live refresh and hide newer hazard/WBGT fields.

Fix:

- detect legacy rows before derived WBGT backfill;
- attempt live refresh first;
- keep valid legacy core values as honest fallback when live fails.

### Alert quiet-hours determinism

Wall-clock-dependent orchestration caused quiet-hours/dedupe/threshold tests to vary with CI execution time.

Fix:

- restore one deterministic quiet-hours evaluation seam in the orchestrator;
- keep the Alert Decision Engine as suppression-order source of truth.

### HRV graceful degradation

One unavailable optional sleep table could erase otherwise available synchronized HRV/exercise context.

Fix:

- read optional health-intelligence signals independently;
- preserve available HRV;
- continue preventing SDNN/RMSSD baseline mixing.

### Vanilla PostgreSQL / Supabase auth migration gate

Newer RLS migrations using `auth.uid()` were not registered for vanilla CI databases without the Supabase `auth` schema.

Fix:

- register current auth-dependent migrations in `init_db.py`;
- add regression test that scans executable SQL for `auth.uid()` / `auth.users`;
- strip SQL comments before scanning so compatibility migrations mentioning auth only in comments are not falsely skipped.

---

## 6. Verified CI evidence

### Backend CI #250

- GitHub Actions run: `34181330042`
- workflow: `Backend CI`
- working-branch head: `a071b68c3b800f8383212250bc4245c24aeb2b6e`
- PR merge SHA executed by Actions: `9cb86c89efb7e6973e19408ab6e326304839c9e0`
- conclusion: **SUCCESS**

Verified steps:

- compile/backend gate: **PASS**;
- complete pytest suite: **PASS / 100% executed**;
- coverage requirement 70%: **PASS**, actual **77.18%**;
- dependency `pip-audit`: **PASS — no known vulnerabilities found**;
- environment security check: **PASS**;
- historical risk validation: **4/4 PASS**;
- DB initialization on vanilla PostgreSQL: **PASS**;
- migration idempotence second run: **PASS, 0 newly applied**;
- retention dry run: **PASS**;
- DB smoke flow: **PASS**.

DB smoke verified representative flows including auth, profile creation, symptom logging, environment/risk/recommendations, subscription/webhook idempotence, settings, briefing schedule, notification registration/dispatch health, Dashboard, Planner, privacy export/delete, cross-account rejection and post-delete auth invalidation.

### CI limitations / non-evidence

- `OPENAI_API_KEY` is intentionally absent in this CI job; AI connection check reported SKIP/template fallback. This is **not** live-AI production evidence.
- CI is not physical-device QA.
- CI does not establish current App Store/Play/Cloudflare deployed Git SHA.

### Non-blocking warnings observed

- Starlette/httpx deprecation warning;
- `datetime.utcnow()` deprecation warning;
- short test HMAC key warning in Supabase auth integration fixtures;
- GitHub Actions Node 20 → 24 deprecation warning.

Classify as P2 tech debt unless later evidence raises impact.

---

## 7. iOS baseline — verified

The existing iOS Action planner already:

- loads real day-plan data;
- exposes freshness/data quality/sources/missing metrics;
- loads activity catalog;
- loads saved places;
- requests an activity plan;
- handles Premium-required responses;
- displays recommended start and activity windows;
- records Protected Day events;
- emits planner/activity analytics.

Existing `ActivityPlanRequest` already supports:

- `durationMinutes`;
- `intensity`;
- `earliestStart`;
- `latestStart`;
- `placeId`.

Current UI request path still sends duration/intensity/time flexibility as defaults/nil.

### Revised Action mobile gap

**P0/P1 for 1.2 UX:** expose compact user-controlled duration and intensity first, using the existing Planner card and existing API. Do not create a new screen or redesign the product.

Later sub-slices:

- earliest/latest flexibility;
- Add to Calendar;
- durable plan lifecycle only if required.

---

## 8. Android baseline — verified

Android already has core parity for:

- activity catalog;
- selected activity;
- saved place;
- activity plan request;
- windows/recommended start;
- Premium handling;
- Protected Day event recording;
- planner/activity analytics.

Current ViewModel uses catalog default duration/intensity and has no selected duration/intensity state.

### Revised Action mobile gap

**P0/P1:** add duration + intensity controls to the existing Planner card using current Android View renderer and API contract, with iOS behavior parity.

---

## 9. Production source-of-truth status

Captured separately in:

`docs/_operator/HIAIR_PRODUCTION_SOURCE_OF_TRUTH.md`

Current known state:

- public iOS HiAir 1.1: verified as public, Git SHA **UNKNOWN**;
- current TestFlight build/SHA: **UNKNOWN**;
- current Android public/internal track: requires direct console verification;
- `api.hiair.io` is canonical backend endpoint, deployed Git SHA **UNKNOWN**;
- `hiair.io` is canonical web domain, deployed Git SHA **UNKNOWN**.

Do not upgrade UNKNOWN to PASS without external evidence.

---

## 10. Revised feature status

| Capability | Current classification | Notes |
|---|---|---|
| Forecast Truth | EXISTS_NEEDS_HARDENING / historical deployed evidence | live SHA still unknown |
| Activity catalog | ALREADY_IMPLEMENTED | backend + iOS + Android |
| Deterministic Action scoring | ALREADY_IMPLEMENTED / HARDENED | reusable core |
| Best Time ranking | RESOLVED_IN_BRANCH | CI verified |
| Duration/intensity customization | PARTIAL | API ready; mobile controls next |
| Time flexibility | PARTIAL | API ready; UI not exposed |
| Saved-place Action planning | ALREADY_IMPLEMENTED | backend/mobile |
| Personal Load input | ALREADY_IMPLEMENTED | baseline regression fixed |
| Calendar | MISSING/UNKNOWN | separate platform slice |
| Plan lifecycle | MISSING | Protected Day event currently used |
| Multi-hazard Action weighting | PARTIAL | canonical hazard reconciliation needed |
| Action analytics | PARTIAL | useful existing events; taxonomy hardening remains |
| Android parity | PARTIAL | revised controls missing |
| Physical-device QA | QA_PENDING | required before production-ready claim |

---

## 11. Current verdict

**Verdict: `IN_PROGRESS`**

### Completed / verified in this branch

- Phase 0 baseline audit started and source-of-truth drift documented;
- Action Best Time ranking correctness fixed;
- regression tests added;
- pre-existing environment/alerts/HRV CI regressions fixed;
- vanilla DB migration gate hardened;
- full backend CI + security audit + DB smoke green.

### Remaining P0/P1

- P0/P1: repository/release provenance and branch-governance drift;
- P1: iOS + Android duration/intensity Action controls;
- P1: time-flexibility UX and calendar integration sequencing;
- P1: multi-hazard Action weighting reconciliation;
- P1: physical-device QA and current production/store SHA evidence;
- product decision: free vs Premium Action entitlement.

### Next three actions

1. implement and test iOS + Android duration/intensity controls using existing Action API;
2. add time-flexibility/calendar sub-slices with platform-specific QA rather than expanding backend prematurely;
3. capture production App Store/Cloudflare/Android release provenance and perform physical-device QA before any production-ready verdict.
