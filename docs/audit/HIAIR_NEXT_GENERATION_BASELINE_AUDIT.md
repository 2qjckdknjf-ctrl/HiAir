# HiAir Next-Generation Baseline Audit

**Status:** IN_PROGRESS  
**Branch:** `codex/hiair-nextgen-phase0-action`  
**Upstream:** `feat/hiair-1.2-best-time-planner`  
**Purpose:** establish real source-of-truth before implementing the revised HiAir 1.2–1.6 roadmap.

## 1. Repository governance — current evidence

- GitHub repository: `2qjckdknjf-ctrl/HiAir`.
- GitHub default branch is currently `cursor/bootstrap-ci-and-tooling`, not `main`.
- `main` currently points to `23eeea664d210dc7f539f2a301dc54042d64e02f`.
- `main` is currently reported as unprotected.
- Active documented upgrade stack is `feat/hiair-1.2-best-time-planner`.
- Comparison `main...feat/hiair-1.2-best-time-planner` is **diverged**: the upgrade branch is 22 commits ahead and 110 commits behind `main`, merge base `537090b335f40cdad4a1526e469067a24b112add`.
- Therefore neither the GitHub default branch nor a naive `main` checkout can be treated as the complete product source-of-truth without reconciliation.

### Governance finding

**P0/P1 source-of-truth risk:** release/product code and repository governance have drifted. Do not change the GitHub default branch or merge the upgrade stack directly into `main` until the production release baseline is mapped and branch history is reconciled.

---

## 2. Existing HiAir 1.2 backend — verified in current working branch

The existing activity planner is real and substantial. It must be hardened, not replaced.

### Existing API

- `GET /api/planner/activities`
- `POST /api/planner/activity-plan`

`POST /activity-plan` currently:

- authenticates the user;
- enforces the `extended_forecast` entitlement;
- resolves a user-owned profile;
- optionally resolves a user-owned saved place;
- loads environment for the selected location;
- loads real forecast or returns an honest unavailable state;
- overlays forecast current data;
- builds Personal Load input from wearables;
- calls deterministic `activity_plan_engine.build_activity_plan()`;
- returns forecast provenance/freshness/quality/missing metrics.

This is aligned with the product integrity rule that AI must not determine safety scores.

### Existing activity catalog

Verified activities:

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

Existing intensity enum:

- low
- moderate
- high

Existing tier enum:

- best
- acceptable
- avoid

### Compatibility decision

The next-generation spec proposed `light/moderate/high` and `best/good/acceptable/avoid/unavailable` as conceptual vocabulary. Existing public contracts already use `low/moderate/high` and `best/acceptable/avoid`. Do **not** rename public enums merely to match the roadmap. Any new semantic tier must justify a backward-compatible migration.

---

## 3. Existing deterministic Action Engine — strengths

Verified strengths:

- deterministic scoring;
- no LLM in core scoring path;
- truthful `forecastAvailable=false` when there are no hourly forecast points;
- real hourly inputs are used;
- air-unknown cases are prevented from being treated as safe;
- Personal Load can influence high-intensity recommendations;
- child/playground caution exists;
- outdoor-work adjustment exists;
- beach has UV-aware logic;
- ventilation has separate scoring logic rather than being treated as exercise;
- outputs structured reason codes;
- windows include confidence;
- data source/freshness/quality/missing metrics propagate to the response.

These are reusable production assets.

---

## 4. Existing Action Engine — identified gaps

### GAP A — `recommendedStart` is first-valid, not best-ranked

Current `_pick_recommended_start()` scans chronologically and returns the first contiguous chunk matching the preferred tier. It does not compare all valid candidate chunks by aggregate score/confidence.

Impact:

- a 07:00 BEST slot scoring 76 may be recommended over a 19:00 BEST slot scoring 95;
- the user-facing claim “Best time” can therefore mean “first acceptable Best-tier slot”, not mathematically strongest candidate.

Priority: **P0 for HiAir 1.2 Action product integrity.**

Required fix:

- generate all duration-valid candidate start windows;
- respect earliest/latest constraints;
- rank tier first, then deterministic aggregate score, then confidence/data quality, with a documented deterministic tie-break;
- add tests proving a later, higher-quality BEST candidate wins over an earlier lower-scoring BEST candidate.

### GAP B — duration is approximated in whole forecast hours

`ceil(duration_minutes / 60)` is used to determine the number of forecast points required.

This is safe/conservative for some cases but coarse for 15/30/45/90-minute activities and may distort ranking around hour boundaries.

Priority: **P1.**

Action:

- document current hourly-resolution limitation;
- evaluate weighted partial-hour scoring rather than pretending precision the forecast grid cannot support;
- do not invent sub-hour environmental values unless provider data supports them.

### GAP C — `confidence` for merged windows is not aggregate

Window confidence is derived from one environment point (effectively the last point in the run), rather than a conservative/aggregate confidence across the whole window.

Priority: **P1.**

### GAP D — action lifecycle is not a first-class domain entity

Current response has no `planId`, persistence or explicit accept/dismiss/complete lifecycle. Mobile records `workout_moved` through Protected Day events instead.

This is enough for the old planner but not ideal for the future recommendation-learning loop.

Priority: **P1/P2**, depending on whether 1.2 needs calendar/replanning now or can remain additive in a later slice.

### GAP E — activity weighting is still narrow

The explicit scoring path primarily uses heat + air risk, Personal Load, and a beach-specific UV rule. The repository already has multi-hazard capabilities, so pollen/smoke/dust/NO2 relevance must be audited before the next Action release claims full multi-hazard activity optimization.

Priority: **P1.**

Do not duplicate the hazard engine. Integrate only canonical existing hazard outputs.

### GAP F — entire activity-plan endpoint is currently Premium-gated

`POST /api/planner/activity-plan` requires the `extended_forecast` entitlement.

The new product rule proposes keeping at least one trustworthy Best Time/core safety decision available for Free while Premium monetizes deeper alternatives/multi-day/personal intelligence.

Priority: **Product decision required during 1.2 spec reconciliation.**

Do not change entitlement behavior until Store/monetization implications are reviewed.

---

## 5. iOS baseline — verified

The iOS planner already:

- loads real day-plan data;
- exposes freshness/data quality/sources/missing metrics;
- loads activity catalog;
- loads saved places;
- requests an activity plan;
- supports Premium-required handling;
- displays activity windows/recommended start;
- records protected-day events such as `workout_moved` and ventilation-window use;
- emits planner/activity analytics.

### iOS product gaps for revised Action

- request currently uses `durationMinutes=nil` and `intensity=nil`, relying on server defaults;
- no user-facing duration control verified in the inspected planner ViewModel path;
- no user-facing intensity control verified;
- no earliest/latest flexibility controls verified;
- no Add to Calendar flow verified;
- no first-class ActionPlan accept/dismiss/complete state verified;
- current flow is still planner-centric rather than a compact “Best action / Best time / Why” primary card.

Priority: **P0/P1 for revised HiAir 1.2 UX.**

---

## 6. Android baseline — verified

Android has parity for the core old planner:

- activity catalog;
- selected activity;
- saved place;
- activity plan request;
- activity windows;
- recommended start;
- Premium handling;
- Protected Day event recording;
- planner/activity analytics.

### Android product gaps for revised Action

- activity plan request uses catalog default duration/intensity;
- no verified user duration/intensity/flexibility controls in the inspected ViewModel;
- no verified Add to Calendar flow;
- no first-class plan lifecycle;
- UX still needs reconciliation with the revised Action-first hierarchy.

Priority: **P0/P1 for Android parity.**

---

## 7. Existing backend test coverage — verified

`backend/tests/test_activity_plan_api.py` currently verifies at least:

- activity catalog is available;
- activity-plan returns BEST/AVOID windows under deterministic fixtures;
- a recommended start is returned;
- missing forecast is represented honestly with `forecastAvailable=false`, no windows and `dataQuality=unavailable`.

### Missing high-value tests identified so far

- later higher-score BEST window beats earlier lower-score BEST window;
- deterministic tie-breaking;
- exact earliest/latest boundary behavior;
- duration spanning multiple points;
- window confidence across mixed-quality points;
- saved-place ownership failure path;
- Personal Load ranking delta;
- child/outdoor worker behavior at boundary values;
- beach UV unavailable/high/extreme cases;
- ventilation missing-air-data behavior;
- timezone/DST behavior in activity candidate ranking;
- entitlement contract behavior.

---

## 8. Current revised feature status — partial audit

| Capability | Current classification | Notes |
|---|---|---|
| Forecast Truth | EXISTS_NEEDS_HARDENING / deployed evidence in existing docs | Must reconcile live SHA |
| Activity catalog | ALREADY_IMPLEMENTED | Backend + iOS + Android |
| Activity deterministic scoring | EXISTS_NEEDS_HARDENING | Core is reusable |
| Best Time ranking | PARTIAL | First-valid vs best-ranked gap |
| Duration/intensity customization | PARTIAL | API supports values; inspected mobile flows rely on defaults |
| Time flexibility | PARTIAL | API has earliest/latest start; inspected mobile does not expose it |
| Saved-place Action planning | ALREADY_IMPLEMENTED | Existing endpoint/mobile support |
| Personal Load input | ALREADY_IMPLEMENTED | Consent/runtime audit still required |
| Calendar | MISSING/UNKNOWN | Not verified in Action flow |
| Plan lifecycle | MISSING | Protected Day event used instead |
| Multi-hazard Action weighting | PARTIAL | Requires hazard-engine reconciliation |
| Action analytics | PARTIAL | Useful events exist; taxonomy needs normalization |
| Android parity | PARTIAL | Core exists; revised controls/UX missing |
| Physical device QA | QA_PENDING | Required by project rules |

---

## 9. Immediate next engineering slice

The first safe implementation change should be **Action candidate ranking hardening** because it:

1. directly fixes the semantic correctness of “Best time”;
2. is backend-local and deterministic;
3. does not require schema migration;
4. can preserve the existing public API contract;
5. can be covered with unit/API tests;
6. improves both iOS and Android immediately because both already consume `recommendedStart`.

### Planned implementation

- replace first-valid selection with deterministic candidate ranking;
- keep `recommendedStart` response field backward compatible;
- avoid enum/API breaking changes;
- add regression tests;
- then proceed to mobile duration/intensity/flexibility controls after API behavior is stable.

---

## 10. Audit status

**Verdict:** `IN_PROGRESS`

### Known high-priority findings

- P0/P1: repository source-of-truth governance drift;
- P0: Best Time selection semantics are not truly best-ranked;
- P1: mobile Action customization is incomplete;
- P1: multi-hazard Action integration needs reconciliation;
- P1: physical production/mobile QA evidence remains required;
- Product decision: Free vs Premium Action entitlement needs explicit reconciliation.

### Next three actions

1. implement and test deterministic Best Time candidate ranking;
2. complete production/release SHA matrix and branch reconciliation;
3. write `docs/roadmap/HIAIR_1_2_ACTION_SPEC.md` from the audited code before larger mobile/API changes.
