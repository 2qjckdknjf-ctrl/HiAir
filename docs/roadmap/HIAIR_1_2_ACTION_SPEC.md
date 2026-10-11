# HiAir 1.2 — Action Implementation Spec

**Status:** IN_PROGRESS  
**Branch:** `codex/hiair-nextgen-phase0-action`  
**Parent roadmap:** `docs/roadmap/HIAIR_MASTER_SPEC_2026_2027.md`  
**Audit:** `docs/audit/HIAIR_NEXT_GENERATION_BASELINE_AUDIT.md`

## 1. Goal

Turn the existing Best Time / Activity Planner into a product-grade Action experience without replacing the current deterministic engine or breaking the current public mobile API.

Primary user question:

> **When is the best time for me to do this activity?**

The current implementation already provides a strong technical baseline. This release is a hardening + UX completion effort, not a rewrite.

---

## 2. Existing canonical implementation

Backend:

- `backend/app/api/planner.py`
- `backend/app/models/activity_plan.py`
- `backend/app/services/activity_plan_engine.py`
- `backend/tests/test_activity_plan_api.py`

Current routes:

- `GET /api/planner/activities`
- `POST /api/planner/activity-plan`

Mobile:

- iOS: `mobile/ios/HiAir/Screens/DailyPlannerView.swift`
- iOS networking/models via current `APIClient` contracts
- Android: `mobile/android/app/src/main/java/com/hiair/ui/planner/DailyPlannerViewModel.kt`
- Android networking via current `ApiClient`

Do not create `/api/v2/actions/*` in the first slice. The existing activity planner route is additive, authenticated and already used by both native clients. A new versioned API is justified only if later lifecycle/persistence requirements cannot be introduced compatibly.

---

## 3. Contract decisions

Preserve current public enum values:

### Activity intensity

- `low`
- `moderate`
- `high`

Do not rename `low` to `light` simply because the next-generation roadmap used conceptual wording.

### Window tiers

- `best`
- `acceptable`
- `avoid`

Do not introduce `good` or `unavailable` as breaking enum values in the first implementation slice. `forecastAvailable=false` + `dataQuality=unavailable` is already the truthful unavailable contract.

### Existing activities

Preserve:

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

Any new/custom activity must be a later additive change with scoring semantics and tests.

---

## 4. P0 — Correct Best Time ranking

### Current defect

`_pick_recommended_start()` currently scans chronologically and returns the first contiguous chunk whose points have the preferred tier.

Therefore `recommendedStart` may not be the highest-scoring valid candidate.

### Required behavior

For each preferred tier in order:

1. `BEST`
2. `ACCEPTABLE`

build all candidate chunks that:

- satisfy activity duration at the available forecast resolution;
- are entirely within the same preferred tier for the first hardening slice;
- satisfy `earliestStart` / `latestStart` constraints;
- have valid timestamps.

Rank candidates deterministically by:

1. tier priority (BEST before ACCEPTABLE);
2. aggregate candidate score, descending;
3. aggregate/conservative data confidence, descending where available;
4. earliest start as stable tie-break.

### Score aggregation

For the first slice, use a documented deterministic aggregate of the existing hourly scores. Preferred implementation: arithmetic mean rounded only for comparison/output where needed.

Do not add hidden randomization or LLM ranking.

### Confidence

The current engine computes confidence from missing environmental fields. During this slice either:

A. compute candidate confidence from all corresponding environment points (preferred); or
B. if that requires disproportionate refactoring, rank by score only and open a clearly documented P1 for confidence aggregation.

Do not use only the last point as if it represented the whole multi-hour candidate when claiming aggregate confidence.

### Tie-break

Equal tier + score + confidence must resolve to the earliest candidate start. This makes output stable and testable.

---

## 5. P0 tests for ranking

Add deterministic tests proving:

### Test A — later stronger BEST wins

Hourly candidates:

- 07:00 BEST score ~78
- 08:00 non-valid/break or weaker condition
- 19:00 BEST score ~95

For a duration that permits each candidate individually, `recommendedStart` must be 19:00.

### Test B — BEST beats higher numeric ACCEPTABLE

If scoring implementation could numerically create an ACCEPTABLE candidate close to a weak BEST candidate, tier still wins. BEST is product classification priority.

### Test C — deterministic earliest tie-break

Two BEST candidates with equal aggregate score/confidence → earliest start wins.

### Test D — duration continuity

For an activity requiring two forecast points, a single BEST point must not qualify if the following point is AVOID.

### Test E — flexibility bounds

A mathematically strongest candidate outside `earliestStart/latestStart` must not be selected.

### Test F — no forecast

Preserve current truthful behavior:

- `forecastAvailable=false`
- `recommendedStart=null`
- `windows=[]`
- `dataQuality=unavailable`

---

## 6. P1 — Duration and forecast resolution

Current implementation converts duration into required hourly points with `ceil(durationMinutes / 60)`.

Do not fake sub-hour measurements.

For 1.2 Action:

- keep current forecast-grid truth;
- expose user duration choices;
- document the resolution limitation;
- evaluate partial-hour weighting only if it can be computed honestly from provider time resolution;
- never interpolate hazardous conditions merely to produce visually precise 15-minute recommendations.

If the backend provider remains hourly, UI may still display activity duration (e.g. 45 min) while the engine conservatively verifies the containing forecast interval(s).

---

## 7. P1 — Mobile Action controls

Current backend supports duration, intensity, earliest/latest and place selection. Current inspected mobile flows do not expose all of those controls.

### iOS required controls

Add an Action configuration surface using existing Aurora Calm / Deep Glass design system:

- activity selector
- duration selector
- intensity selector
- place selector (existing Saved Places path)
- optional time preference/flexibility
- generate/update recommendation

Do not redesign unrelated screens.

### Android required controls

Feature parity with iOS using existing HiAir Android design tokens/components.

### Suggested duration presets

- 15 min
- 30 min
- 45 min
- 60 min
- 90 min
- 120 min where activity allows

Respect backend min/max contract.

### Intensity

Use existing values:

- Low
- Moderate
- High

Activity defaults remain the initial selected values, not immutable values.

---

## 8. Action-first result hierarchy

The result surface should prioritize decision over raw metrics.

Order:

1. activity
2. recommended time
3. duration/intensity
4. classification
5. concise reason summary
6. `Why this time?`
7. alternative windows
8. provenance/freshness/detail

Example:

> **Best time for your run**  
> 19:20–20:05  
> Lower heat · Better air · Personal load normal

Do not hide data quality/freshness, but do not lead with scientific detail.

---

## 9. Reason codes

Continue structured deterministic reason codes.

Audit current localization mappings before adding codes.

Potential code families:

- heat
- low_heat
- air
- good_air
- aqi
- pm25
- ozone
- uv
- uv_unavailable
- personal_load
- child_caution
- air_data_unavailable

Before claiming multi-hazard Action support, reconcile canonical hazard outputs for pollen/smoke/dust/NO2. Do not duplicate hazard calculations inside `activity_plan_engine.py`.

---

## 10. P1 — Multi-hazard integration

Repository evidence shows a broader hazard engine already exists. The Action engine must consume canonical hazard decisions/scores where appropriate rather than separately rebuilding thresholds.

Audit:

- pollen
- smoke/wildfire
- dust
- NO2
- UV beyond beach-only behavior

For each activity define relevance/weighting only when scientifically/product justified.

Examples:

- running/cycling: higher inhalation load makes air hazards more consequential;
- beach: UV/heat are highly relevant;
- playground/child profile: conservative thresholds;
- ventilation: outdoor air hazard quality is primary; exercise intensity is irrelevant.

No medical claims.

---

## 11. Premium reconciliation

Current `/api/planner/activity-plan` is gated behind `extended_forecast`.

New product strategy proposes a useful free safety/action layer with Premium for deeper intelligence.

Do not change entitlement behavior in the ranking slice.

Create a separate product/engineering decision before store behavior changes. Evaluate:

### Candidate Free

- one trusted Best Time for today
- core safety reasons
- severe hazard information

### Candidate Premium

- multiple alternatives
- multi-day Action planning
- saved recurring activities
- advanced personal context/history
- deeper comparisons

Any entitlement migration requires Store/analytics/regression review.

---

## 12. Calendar

After core Action controls are stable, add native **Add to Calendar** if the product decision remains approved.

### iOS

- EventKit
- explicit permission/confirmation
- event contains only planned activity context HiAir needs

### Android

- prefer system calendar intent/provider architecture that minimizes permissions

Do not ingest or upload unrelated calendar contents.

Analytics event candidate:

- `action_plan_calendar_added`

---

## 13. Action lifecycle

Do not create persistence merely because the roadmap mentioned `planId`.

First audit whether existing Protected Day events + analytics provide sufficient behavior evidence.

If explicit plan lifecycle is required for replanning/calendar/completion, introduce it additively with:

- plan ID
- generated_at
- accepted_at
- completed_at or dismissed_at
- user/profile ownership
- selected window
- activity parameters
- no unnecessary raw health snapshot

Any new table requires RLS + export/delete/retention updates.

---

## 14. Analytics normalization

Existing events include variants such as:

- activity_plan_fetch_started
- activity_plan_loaded
- activity_plan_created
- activity_plan_fetch_failed
- activity_plan_marked_planned
- activity_plan_followed
- protected_day_event_recorded

Do not blindly rename live events and break dashboards.

Create/update the taxonomy with alias/deprecation strategy if the next-generation naming (`action_*`) is adopted.

Never send raw HRV/RHR/symptoms/exact coordinates.

---

## 15. Error and truth UX

Preserve truthful states:

- live/complete
- partial
- cached/freshness where supported
- unavailable

If forecast is unavailable, do not manufacture a recommendation from the current snapshot.

If required air data is unknown, do not classify the window safe.

Show user-friendly explanations such as:

> We don't have reliable forecast data for this location right now.

without pretending a numeric answer exists.

---

## 16. Privacy/security regression

Action work must not weaken:

- profile ownership checks
- Saved Place ownership
- Supabase/Auth session isolation
- Health consent
- entitlement validation
- export/delete
- secrets handling

Add/retain tests for user-owned place/profile resolution where practical.

No exact GPS or health raw values in product analytics.

---

## 17. Definition of Done — HiAir 1.2 Action

### Backend

- true deterministic best-ranked `recommendedStart`
- no breaking public contract without explicit migration
- honest no-forecast behavior
- activity duration/intensity/flexibility supported
- multi-hazard integration audited and either implemented or explicitly deferred
- tests green

### iOS

- activity/duration/intensity controls
- place selection
- recommendation card hierarchy
- alternatives + Why
- truthful unavailable/partial states
- Premium handling
- accessibility/localization
- physical-device QA

### Android

- functional parity for the Action core
- same truth/entitlement behavior
- accessibility/localization
- physical-device QA as release-critical

### Cross-cutting

- analytics taxonomy
- privacy/retention updates if persistence changes
- production/backend smoke after deploy
- no auth/subscription/Health/privacy regressions
- evidence-based release status

---

## 18. First Codex implementation slice — exact order

1. inspect current `activity_plan_engine.py` and existing tests;
2. replace first-valid recommended-start selection with deterministic candidate ranking;
3. keep API response backward compatible;
4. add ranking regression tests;
5. run focused backend tests;
6. run relevant broader backend integrity tests/gates;
7. fix failures;
8. update baseline audit with actual evidence;
9. only then start mobile controls.

### Required status after slice

- `CODE_COMPLETE` only if code + tests have been executed successfully;
- otherwise `QA_PENDING` or `PARTIAL`;
- do not claim production verification until deployed/runtime evidence exists.
