# HiAir — Master Product & Engineering Spec 2026–2027

**Project:** HiAir  
**Execution target:** Codex / Cursor Agent  
**Repository:** `2qjckdknjf-ctrl/HiAir`  
**Working branch:** `codex/hiair-nextgen-phase0-action`  
**Upstream upgrade stack:** `feat/hiair-1.2-best-time-planner`  
**Product direction:** Personal Environmental Intelligence System → Personal Climate OS  
**Execution model:** audit → design → implement → test → runtime evidence → PR  

This document supersedes the old release numbering as the next-generation product plan. It MUST be reconciled against real production code before implementation. Existing capabilities must be reused and hardened rather than reimplemented.

---

## 1. Product mission

HiAir must evolve from an environmental-data application into a decision system that answers:

> **What should I do, when, where, and why — for me?**

Long-term loop:

`Environment → Person → Personal Risk → Best Action → User Action → Learning → Better Recommendation`

Core promise:

> **Know the best time to go outside.**

Differentiation:

`Environment × Body × Location × Time × Activity × Behavior`

The product must not compete by showing more raw weather/AQI numbers. It must turn trusted environmental and personal context into clear, explainable actions.

---

## 2. Non-negotiable integrity rules

### 2.1 Deterministic safety core

LLMs MUST NOT calculate AQI, heat risk, UV risk, pollen risk, smoke risk, environmental exposure, safe windows, route exposure, work/rest limits, or final safety classifications.

Required flow:

`Trusted Data → Normalization → Deterministic Engines → Structured Result → Optional AI Explanation`

AI may explain, summarize, compare and translate already-computed facts. It may not invent measurements or override deterministic safety logic.

### 2.2 No fake data

Important environmental fields should preserve provenance and freshness where applicable:

- source/provider
- observed_at
- issued_at
- valid_for
- fetched_at
- freshness
- quality/confidence
- classification: observed / forecast / derived / estimated / cached / unavailable

Unavailable data must stay unavailable. Never use `0` as a silent substitute for missing pollution/pollen/UV/etc.

### 2.3 Wellness, not diagnosis

HiAir must use association/pattern/baseline/wellness language. Do not claim diagnosis, treatment, causation or guaranteed health outcomes.

### 2.4 Safety information is not a paywall lever

Free users retain essential current safety information and important severe alerts. Premium monetizes deeper planning, personalization, history, automation and convenience.

---

## 3. Phase 0 — Reality and source-of-truth audit

Before writing new feature code, determine the factual state of:

- GitHub default branch and `main`
- production iOS build/version/SHA if traceable
- production Android track/version/SHA if traceable
- backend production SHA and migration state
- TestFlight / Play Internal / Play Production status
- existing feature branches and open PRs
- branch protection / release governance
- actual production feature coverage

Build a matrix:

| Surface | Version | Git SHA | Branch | Production? | Evidence |
|---|---|---|---|---|---|
| iOS | | | | | |
| Android | | | | | |
| Backend | | | | | |
| Website | | | | | |

Classify every relevant capability as:

- PRODUCTION
- PARTIAL
- EXPERIMENTAL
- BRANCH_ONLY
- ROADMAP
- UNKNOWN

At minimum audit:

- current risk
- real forecast truth
- Best Time/activity planner
- pollen/smoke/UV/dust/NO2
- Smart Alerts
- Saved Places
- Family
- Travel
- Work Safety
- HealthKit
- Health Connect
- Personal Load
- Health Intelligence
- Symptoms
- Personal Patterns
- Morning Briefing
- Premium
- privacy export/delete
- widgets
- Live Activities
- Apple Watch
- Wear OS
- routes
- indoor/home integrations
- analytics/experiments

Required output:

`docs/audit/HIAIR_NEXT_GENERATION_BASELINE_AUDIT.md`

Also create/update:

`docs/_operator/HIAIR_PRODUCTION_SOURCE_OF_TRUTH.md`

Truth hierarchy:

1. production runtime evidence
2. production code
3. release branch code
4. tests
5. canonical technical docs
6. README
7. old roadmaps
8. marketing text

Never convert `UNKNOWN` into `PASS`.

---

# 4. Next five product releases

The revised release sequence is:

1. **HiAir 1.2 — ACTION**
2. **HiAir 1.3 — AMBIENT**
3. **HiAir 1.4 — ROUTES**
4. **HiAir 1.5 — CLIMATE TWIN**
5. **HiAir 1.6 — HOME + CARE**

Conceptual progression:

`Data → Decision → Proactivity → Spatial Exposure → Personal Learning → Environmental Automation`

Do not combine all five releases into one implementation branch or PR.

---

# 5. HiAir 1.2 — ACTION

## Goal

Make the strongest and clearest experience in HiAir answer:

> **When is the best time for me to do this activity?**

The current Best Time/activity-planner implementation must be audited first and reused where sound.

## Initial activities

- running
- walking
- cycling
- hiking
- dog_walk
- kids_outdoor
- outdoor_sport
- beach
- outdoor_work
- ventilation
- custom where the existing architecture supports it safely

## Inputs

- activity type
- duration
- intensity: light / moderate / high
- earliest start / latest end
- location
- timezone
- flexibility
- personal profile/sensitivity
- Personal Load / recovery context when consented and available

## Output

Windows should be classified as:

- best
- good
- acceptable
- avoid
- unavailable

Return reason codes, not hard-coded UI prose.

Example deterministic result:

```json
{
  "classification": "best",
  "score": 87,
  "reasonCodes": [
    "temperature_improving",
    "uv_lower",
    "pm25_stable",
    "personal_load_normal"
  ]
}
```

The score is a ranking/decision score, not a medically precise measurement.

## Action domain

Prefer explicit models such as:

- ActionPlanRequest
- ActionCandidateWindow
- ActionRecommendation
- ActionReason
- ActionConstraint
- ActionPlan

Do not introduce a second planner architecture if the existing activity-plan API already covers this domain. Extend/harden the canonical implementation.

## API

Preserve existing production clients. Prefer additive/versioned contracts only when necessary.

Potential future surface if existing endpoints cannot cleanly evolve:

- `POST /api/v2/actions/plan`
- `GET /api/v2/actions/{planId}`
- `POST /api/v2/actions/{planId}/accept`
- `POST /api/v2/actions/{planId}/complete`
- `POST /api/v2/actions/{planId}/dismiss`

The existing `/api/planner/activity-plan` must be audited before any new route is created.

## UX hierarchy

`ACTION → TIME → CONFIDENCE → WHY → RAW DATA`

Primary UI example:

**Best time for your run**  
19:20–20:05  
Low environmental load · 45 min  
`[Plan this]`

Secondary action: `Why this time?`

Do not place a large scientific dashboard before the decision.

## Calendar

Support native Add to Calendar where appropriate:

- iOS: EventKit + explicit user confirmation
- Android: system calendar flow / supported native integration

Do not ingest unrelated calendar contents.

## Analytics

At minimum:

- action_planner_opened
- action_type_selected
- action_plan_generated
- action_plan_generation_failed
- action_window_viewed
- action_window_selected
- action_plan_accepted
- action_plan_calendar_added
- action_plan_dismissed
- action_plan_completed

Do not send raw health values or precise GPS to product analytics.

## Premium

Free:

- core current recommendation
- at least one trustworthy Best Time where available
- important reasons and severe safety information

Premium candidates:

- alternative windows
- advanced activities
- multi-day planning
- saved recurring activities
- deeper personal context
- advanced comparisons/history

## 1.2 Definition of Done

- deterministic Action/Planner engine verified
- real forecast only; honest missing data
- existing 1.2 implementation reconciled, not duplicated
- iOS complete
- Android parity
- calendar integration if accepted in final audit
- analytics
- localization
- accessibility
- backend tests
- API contract tests
- iOS tests
- Android tests
- privacy/retention matrix updated for any new persisted data
- staging smoke
- production smoke when deployed
- physical-device QA
- no auth/Premium/Health/privacy regression

---

# 6. HiAir 1.3 — AMBIENT

## Goal

Make HiAir useful without requiring the user to open the app.

Surfaces:

- actionable Smart Alerts
- widgets
- Lock Screen
- Live Activities
- Apple Watch
- Wear OS where practical

Notifications must describe an action opportunity rather than simply report a metric.

Good:

> Air quality is expected to worsen in 50 minutes. If you want to walk today, the next 35 minutes are your best window.

Bad:

> AQI 103.

Alert engine requirements:

- threshold crossing
- trend detection
- best-window opening/closing
- forecast deterioration/improvement
- personal sensitivity
- saved activity/place
- quiet hours
- dedupe
- cooldown
- timezone
- priority
- expiration

Track candidate / sent / suppressed / opened / acted / dismissed / expired and suppression reason.

Ambient implementation must be battery-conscious and avoid continuous location/background polling.

Release requires real-device evidence for APNs, FCM, permission-denied behavior, quiet hours, timezone changes, dedupe, widgets/watch surfaces and account isolation.

---

# 7. HiAir 1.4 — ROUTES

## Goal

Answer:

> **Where should I go?**

Compare plausible walking/running/cycling routes by environmental exposure using only data resolution the providers actually support.

Potential factors:

- PM2.5 / PM10 / NO2
- heat
- UV
- smoke
- pollen
- duration
- activity intensity
- reliable shade/green-space proxies only if the data source supports them

Introduce a carefully named internal concept such as **Environmental Exposure Load**. Do not market it as a medical dose.

Conceptually:

`environmental concentration × time × activity intensity adjustment × personal sensitivity adjustment`

Document the production formula and uncertainty.

Create a provider abstraction:

- RouteProvider
- RouteCandidate
- RouteSegment
- RouteGeometry

Architecture:

`route polyline → sampled points → forecast time alignment → segment exposure → route aggregate`

Batch/cache provider calls. Do not imply street-level precision when the source grid cannot support it.

Location privacy:

- no raw coordinates in product analytics
- no indefinite exact-route retention by default
- export/delete/retention rules required

---

# 8. HiAir 1.5 — CLIMATE TWIN

## Goal

Create an explainable personal environmental baseline from consented, sufficient data.

Start with statistics and deterministic adaptation, not a black-box medical model.

Potential baselines:

- 7-day
- 30-day
- longer/seasonal rolling baseline where data is sufficient

Signals may include:

- HRV
- resting HR
- sleep
- exercise/activity
- symptoms
- environmental exposure
- recommendation behavior

Preferred status language:

- within personal baseline
- slightly outside baseline
- meaningfully outside baseline
- insufficient data

Personal associations must include sample count, window and confidence, and never use causal language.

Example:

> On high-pollen afternoons following shorter-than-usual sleep, you log respiratory symptoms more often. Confidence: Moderate. Based on 18 relevant days.

Behavioral feedback may tune preference/ranking, but must not silently alter deterministic safety thresholds.

Prototype a user-facing **Environmental Load / Outdoor Load** concept only with documented uncertainty.

Candidate North Star: **Protected Days per Active User**. Define it mathematically before adopting it.

Climate Twin data must remain consent-scoped, user-scoped, exportable, deletable, retained under explicit policy, and protected by cross-account regression tests.

---

# 9. HiAir 1.6 — HOME + CARE

## Goal

Expand from `ME + OUTSIDE` to `ME + FAMILY + HOME + OUTSIDE`.

Home inputs may include:

- indoor PM2.5
- CO2
- temperature
- humidity
- VOC where trustworthy
- purifier/HVAC state

Core decision:

`Indoor State + Outdoor State + Forecast → Best Home Action`

Ventilation must be a separate decision domain from exercise.

Initial automation should prefer:

`recommendation → user confirmation → action`

before fully autonomous control.

Evaluate Matter / Apple Home / Google Home / supported sensor/purifier APIs based on real actionable value, license and platform constraints.

Care Intelligence should support household/profile relationships with explicit permissions. Never assume one adult can see another adult's health-derived data.

Permission domains should distinguish:

- environmental status
- location
- health-derived personalization
- symptoms
- alerts

Release requires RBAC/privacy tests, revocation, export/delete and cross-user leakage testing.

---

# 10. Shared architecture

Preserve the existing native stack unless repository truth says otherwise:

- iOS: Swift / SwiftUI
- Android: Kotlin
- Backend: Python / FastAPI
- DB/Auth: PostgreSQL/Supabase

No big-bang rewrite.

Target domain boundaries when touched:

- Environment
- Forecast
- Risk
- Action
- Alerts
- Routes
- Exposure
- Health
- Symptoms
- Insights
- ClimateTwin
- Places
- Travel
- Family
- Home
- Premium
- Analytics
- Privacy

Shared:

- Networking
- Auth
- Storage
- Notifications
- DesignSystem
- Localization
- Accessibility
- Observability

If large session/coordinator files are touched, decompose incrementally rather than inventing an unrelated architecture project.

---

# 11. Feature flags

Large new systems must be independently controllable according to existing repo conventions.

Conceptual flags:

- HIAIR_ACTION_V2
- HIAIR_AMBIENT
- HIAIR_ROUTE_INTELLIGENCE
- HIAIR_CLIMATE_TWIN
- HIAIR_HOME_CARE
- HIAIR_AI_EXPLANATIONS

AI explanation must be separately disableable. Core deterministic behavior must continue without AI.

Flags default OFF until verification gates pass unless the current implementation has an established safe rollout convention.

---

# 12. Privacy, health and security

Preserve:

- Supabase Auth isolation
- bearer-token validation
- RLS
- refresh-token behavior
- OAuth behavior
- delete-account flow
- privacy export
- secrets hygiene

HealthKit/Health Connect:

- explicit consent
- account-scoped data
- app functional when permission denied
- revoke/delete behavior tested
- no raw health values in product analytics
- no advertising use

For every new persistent table update the data-retention/privacy matrix with:

| Table | User data? | Export | Delete | Retention | RLS |
|---|---|---|---|---|---|

No secrets in repo, logs, screenshots, CI artifacts or docs.

---

# 13. Time, units, localization and accessibility

Recommendations must use the location's timezone, not blindly the device timezone.

Test DST and travel cases.

Backend domain logic should use canonical units; UI may display regional °C/°F, km/mi, local date/time conventions and supported AQI schemes.

Backend decision logic should return reason/action codes rather than localized prose.

Preserve current languages; architecture must remain extensible for additional markets and RTL.

Accessibility is a release requirement: Dynamic Type/VoiceOver/Reduce Motion and TalkBack/font scaling/semantics/contrast/touch targets. Risk meaning may not depend on color alone.

---

# 14. Observability and analytics

Create/update:

`docs/analytics/HIAIR_PRODUCT_EVENT_TAXONOMY.md`

Observe at minimum:

- provider availability/latency/freshness
- forecast missing rate
- action generation latency/failures
- alert candidate/suppression/send/failure
- route-provider failures and route-analysis latency
- Climate Twin recomputation
- device integration failures

No raw health records or secrets in logs.

Candidate product metrics:

- Action Plan Adoption Rate
- Recommendation Follow Rate
- Actionable Alert Rate
- Planner Weekly Retention
- Route Selection Rate
- Climate Twin Engagement
- Care adoption
- Premium conversion
- D7/D30 retention

---

# 15. Test and release gates

Each release requires applicable:

Backend:

- unit
- contract
- integration
- DB/RLS
- auth
- privacy
- provider failure
- timezone
- deterministic fixtures

Mobile:

- unit
- networking contract
- state/error/offline
- accessibility
- simulator/emulator
- physical-device QA for release-critical behavior

Regression matrix includes:

- signup/login/logout
- refresh
- Apple auth
- Google auth
- profile/location
- Dashboard
- Planner
- Symptoms
- Insights
- Health connect/revoke
- Premium purchase/restore
- privacy export/delete
- offline
- cold start
- background/foreground

Store readiness must be evidence-based. Do not claim TestFlight/Play/public availability without console/runtime evidence.

Release flow:

`local → CI → staging → internal mobile distribution → physical QA → production backend → phased platform rollout → full release`

Rollback criteria include crash/auth/subscription failures, misleading recommendations, alert spam and material battery regression.

---

# 16. Branch / PR strategy

Do not merge directly to `main`.

The current next-generation work starts on:

`codex/hiair-nextgen-phase0-action`

The branch was created from:

`feat/hiair-1.2-best-time-planner`

The audit must determine whether that upstream branch is still the correct release baseline before implementation PRs are prepared.

Prefer understandable implementation slices rather than one giant PR. For Action, likely slices are:

1. audit + architecture reconciliation
2. deterministic Action domain/engine hardening
3. API/DB/privacy changes only if needed
4. iOS UX
5. Android parity
6. calendar/analytics
7. QA/docs/release closure

Do not create duplicate services/endpoints/components when equivalent production code already exists.

---

# 17. Required Codex execution behavior

Work autonomously and keep progressing until a real external blocker is reached.

Do not stop after merely writing recommendations.

Expected loop:

`inspect → implement → test → fix → retest → document → prepare PR`

Before code changes, record:

- repo
- branch
- HEAD
- working tree status
- production/release baseline
- relevant existing feature code/docs

Do not overwrite unrelated user work or untracked local files.

Use explicit statuses only:

- NOT_STARTED
- IN_PROGRESS
- PARTIAL
- CODE_COMPLETE
- QA_PENDING
- EXTERNAL_BLOCKED
- READY_FOR_REVIEW
- PRODUCTION_VERIFIED

Never say `done`, `production ready` or `fully working` without evidence.

---

# 18. Immediate Codex mission

## Step 1 — full repository reality audit

Inspect the current upgrade branch plus relevant release/feature branches. Reconcile production, App Store/Play evidence, backend deployment evidence and Git governance.

## Step 2 — feature matrix

Classify every requirement as:

- ALREADY_PRODUCTION
- EXISTS_NEEDS_HARDENING
- PARTIAL
- MISSING
- NOT_NEEDED
- CONFLICTS_WITH_CURRENT_ARCHITECTURE

## Step 3 — source-of-truth report

Create:

`docs/audit/HIAIR_NEXT_GENERATION_BASELINE_AUDIT.md`

and:

`docs/_operator/HIAIR_PRODUCTION_SOURCE_OF_TRUTH.md`

## Step 4 — Action-specific spec

Create:

`docs/roadmap/HIAIR_1_2_ACTION_SPEC.md`

It must be based on real current code, especially the existing `/api/planner/activities` and `/api/planner/activity-plan` implementation.

## Step 5 — implement 1.2 Action

Only after audit/spec reconciliation, implement missing/hardening work end-to-end.

## Step 6 — test and fix

Run all applicable backend/iOS/Android tests, CI-equivalent checks, integrity gates and smoke tests. Fix regressions before reporting.

## Step 7 — prepare PR

Do not merge directly. Prepare a reviewable PR with evidence and explicit remaining external blockers.

Final report format:

### Verdict
`READY_FOR_REVIEW / PARTIAL / EXTERNAL_BLOCKED`

### Repository
- branch
- HEAD
- base
- worktree

### Implemented
Concrete changes only.

### Tests
Actual pass/fail evidence.

### Production evidence
Backend / iOS / Android; never invent.

### Privacy/security
Checks performed and findings.

### Remaining blockers
P0 / P1 / P2.

### Next three actions
Exactly the three highest-value next steps.

---

# 19. Long-term destination

After 1.6 and only after consumer retention/value is proven, evolve HiAir Work/B2B separately for construction, logistics, delivery, agriculture, maintenance and other outdoor-work domains. Occupational safety logic must remain an explicit domain with WBGT/workload/PPE/acclimatization/work-rest semantics rather than consumer-copy reuse.

The final product destination is:

> **THE BEST ACTION FOR THIS PERSON RIGHT NOW**

Every architectural and product decision in this roadmap should make that answer more truthful, useful, personal, explainable and actionable.
