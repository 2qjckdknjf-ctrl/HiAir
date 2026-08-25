# HiAir — Master Upgrade Plan 2026

**Project:** HiAir  
**Status:** Canonical product-development roadmap after iOS 1.0 / submitted build 188  
**Date:** 2026-08-21  
**Repository:** `2qjckdknjf-ctrl/HiAir`  
**Baseline:** current release line in `main`, treated as the source baseline for the submitted iOS 1.0 / build-188 candidate  
**Current implementation branch for 1.1:** `feat/hiair-1.1-forecast-truth`

> This document is the canonical upgrade roadmap for HiAir after release 1.0. Future agents, developers and Cursor sessions should use it as the default product-development sequence unless Sasha explicitly replaces or supersedes it.

---

## 1. Product Direction

HiAir should evolve from a strong personalized heat / air-quality wellness application into a **Personal Environmental Intelligence System**.

The long-term product loop is:

**Environment → Person → Risk → Best Action → Learning**

HiAir should not compete as a generic weather or AQI application. Its differentiator is the combination of environmental conditions with personal context from profile, HealthKit / Health Connect, sleep, HRV, heart rate, recent activity, symptoms and behavioral history.

### Core user promise

**Know when it is safe for YOU to go outside — and what to do next.**

### Product integrity rule

Safety-critical or future-facing recommendations must be deterministic, explainable and grounded in real timestamped data. AI/LLM may explain results, but must not invent environmental measurements or decide the underlying risk score.

---

## 2. Baseline: What HiAir 1.0 Already Has

Do not re-implement these as “new” features unless the roadmap explicitly calls for refinement.

### Existing product capabilities

- iOS native SwiftUI application.
- Android native Kotlin application.
- FastAPI + PostgreSQL backend.
- Supabase-backed auth/session architecture.
- location bootstrap and reverse geocoding.
- personalized current environmental risk.
- Dashboard with risk, environmental metrics, recommendations and safe-window presentation.
- HealthKit integration on iOS.
- Health Connect path on Android.
- tiered health consent and account-bound durable consent.
- health daily aggregates and background synchronization.
- steps, distance, energy, exercise, stand, sleep, HR/RHR, HRV, VO2 max, respiratory, SpO2, temperature and related supported health metrics.
- Personal Load scoring using health/activity/environment context.
- Health Intelligence trends and associations.
- Symptoms taxonomy, history, favorites, recents, advanced symptom details and offline drafts.
- Insights 7/30-day views.
- morning/evening/weekly AI reports.
- morning briefing scheduling.
- notification preferences, quiet hours and alert thresholds.
- Premium entitlements.
- StoreKit 2 purchase and restore flow.
- physically verified TestFlight yearly Sandbox Premium activation on build 178 / production API line.
- privacy export/delete flows.
- current deep-glass / Aurora Calm design foundation.

### Existing strengths to preserve

1. Health / wearable intelligence.
2. Personalization.
3. Symptoms and longitudinal context.
4. StoreKit and Premium architecture.
5. Explainable wellness framing.
6. Existing production auth, privacy and consent hardening.

Do not rewrite the application from scratch.

---

# 3. Release Roadmap

## HiAir 1.1 — Forecast Truth

### Goal

Make all future-facing environmental recommendations truthful and forecast-backed.

### Why it is P0

The current planner/safe-window architecture can project future hours mathematically from the current snapshot. Some environmental values may also be heuristically estimated from unrelated metrics. This is acceptable only as an explicitly labeled fallback in non-production experimentation, not as production truth.

### Required changes

#### Backend

- create provider abstraction for weather and air-quality sources;
- introduce normalized hourly environmental forecast model;
- support at least 48h hourly forecast and 7d daily structure where provider data supports it;
- store or cache forecast points with timestamps;
- attach provenance to every point;
- attach freshness / issued-at / observed-at / valid-for metadata;
- store actual/forecast/derived/unavailable semantics;
- add location-local timezone handling;
- support DST correctly;
- remove synthetic production future projection from planner and safe-window generation;
- use real hourly temperature;
- use real hourly apparent temperature / heat index when available;
- use real humidity;
- use real wind and gusts when available;
- use real UV forecast when available;
- use real PM2.5;
- use real PM10 when available;
- use real ozone when available;
- do not silently derive unrelated environmental metrics;
- keep missing values null/unavailable when no trustworthy source exists.

#### Risk / Planner

- consume normalized real forecast points only;
- calculate safe windows from actual forecast data;
- compute risk in location-local time;
- preserve current personalized health/profile adjustments;
- do not let an LLM calculate the score or window.

#### API

Recommended canonical surface:

- current environment;
- hourly forecast;
- personal hourly risk forecast;
- daily planner;
- provenance / freshness fields.

Existing clients should remain backward compatible during migration.

#### iOS / Android

- keep current screen hierarchy;
- replace synthetic data consumption with real forecast response;
- show forecast freshness;
- expose provider/source in an info/detail surface;
- show unavailable state honestly;
- no large redesign in this release.

### Release blocker

**No production Safe Window may be generated from synthetic future environmental values.**

### Definition of Done

- real hourly provider forecast validated against raw provider response;
- timezone tests for Europe, US, GCC and Egypt examples;
- planner contract tests;
- no fake/synthetic production future points;
- device QA on iOS;
- Android parity gate;
- production smoke on `api.hiair.io`;
- telemetry confirms provider freshness and forecast success/failure rates.

### Implementation specification

Use:

`docs/roadmap/HIAIR_1_1_FORECAST_TRUTH_IMPLEMENTATION_PROMPT.md`

Development branch:

`feat/hiair-1.1-forecast-truth`

---

## HiAir 1.2 — Best Time & Activity Planner

### Goal

Turn the planner from a generic hourly risk graph into an activity decision engine.

### User question

**“When is the best time for me to do this activity?”**

### Activities

Initial set:

- Running
- Walking
- Cycling
- Hiking
- Dog walk
- Playground / child outdoor time
- Outdoor sport
- Beach
- Outdoor work
- Ventilation

### Inputs

- activity type;
- duration;
- intensity;
- persona;
- personal sensitivity;
- flexible start time;
- health/recovery context when available.

### Output

Classify time windows into:

- **Best**
- **Acceptable**
- **Avoid**

Return structured reason codes such as:

- heat;
- UV;
- ozone;
- PM2.5;
- PM10;
- humidity;
- personal load;
- short sleep;
- elevated resting HR;
- low HRV versus baseline.

### Product rule

The Action Engine decides. AI only explains.

### KPI

- planner completion rate;
- activity-plan creation rate;
- recommendation-follow rate;
- repeat planner use;
- Premium conversion from planner.

---

## HiAir 1.3 — Multi-Hazard Intelligence

### Goal

Expand from heat + air quality into a market-adaptive environmental safety layer.

### New hazard modules

- UV;
- pollen;
- wildfire / smoke;
- PM10;
- NO2 where data quality allows;
- dust / sand;
- official environmental / heat alerts.

### Regional configuration

#### USA

- heat;
- wildfire smoke;
- pollen;
- UV;
- official alerts.

#### Southern Europe

- heat;
- UV;
- pollen;
- AQ;
- smoke / wildfire.

#### Saudi Arabia

- heat;
- humidity;
- UV;
- dust/sand;
- preparation for occupational heat.

#### UAE

- heat;
- humidity;
- UV;
- dust;
- bilingual English/Arabic UX.

#### Egypt

- heat;
- PM2.5;
- PM10;
- dust;
- Arabic-first Android considerations.

### Architecture

Risk Engine becomes modular:

- Heat Risk
- Air Risk
- UV Risk
- Pollen Risk
- Smoke Risk
- Dust Risk

Then aggregate into a Personal Environmental Risk output.

---

## HiAir 1.4 — Smart Predictive Alerts

### Goal

Increase retention by notifying the user only when an environmental change creates a meaningful action opportunity.

### Examples

- “Air quality is expected to worsen in 90 minutes. Ventilate now.”
- “Tomorrow will be harder on you than today. Your best outdoor window is before 08:15.”
- “Recovery is below your usual baseline. Move the intense workout to the evening window.”

### Required backend layer

**Alert Decision Engine**

Must support:

- change detection;
- threshold crossing;
- event significance;
- personal threshold;
- cooldown;
- deduplication;
- quiet hours;
- local timezone;
- notification reason code;
- audit/telemetry record.

### Anti-spam rule

Do not send notifications for conditions the user cannot act on unless severity is important enough to justify it.

### KPI

- notification open rate;
- action rate;
- opt-out rate;
- spam/dismiss rate;
- 7d/30d retention uplift.

---

## HiAir 1.5 — Family, Saved Places & Travel

### Goal

Expand product value from “me now” to “people and places I care about”.

### Saved Places

- Home
- Work
- Parents
- School
- Vacation

### Family / Caregiver

Support multiple monitored profiles such as:

- child;
- parent;
- elderly relative;
- partner.

Each profile may have its own sensitivity, location and alert rules.

### Travel Mode

- destination forecast before travel;
- compare home vs destination risk;
- activate travel location automatically after location change when appropriate;
- keep timezones correct.

### Monetization

Introduce Family Premium hypothesis only after product behavior is validated.

### KPI

- saved place creation;
- second-profile adoption;
- caregiver alert usage;
- family conversion;
- travel-mode re-engagement.

---

## HiAir 1.6 — Personal Adaptation & Protected Days

### Goal

Turn existing rule-based personalization into a learning personal environmental baseline.

### Personal Baselines

- 7-day;
- 30-day;
- seasonal / rolling baseline where data is sufficient.

### Signals

- HRV;
- resting HR;
- sleep;
- activity;
- workout intensity;
- symptoms;
- environmental exposure;
- recommendation behavior.

### Feedback loop

Example:

1. HiAir recommends moving a run to 20:00.
2. HealthKit detects a workout near 20:00.
3. Recommendation-follow event is recorded.
4. Future personalization uses behavioral history only after sufficient data and guardrails.

### Protected Days

Introduce a user-facing value summary such as:

- high-risk periods avoided;
- workouts moved to safer windows;
- better ventilation windows used;
- reduced poor-air exposure periods.

Suggested North Star:

**Protected Days per Active User**

### Medical-safety rule

Associations are not causation. Do not diagnose. Do not claim treatment effect.

---

# 4. HiAir 2.0 — HiAir Work / B2B

This is a separate product layer on the same environmental intelligence platform.

### Target sectors

- construction;
- delivery;
- logistics;
- oil & gas;
- maintenance;
- landscaping;
- security;
- tourism;
- agriculture.

### Required occupational inputs

- WBGT;
- workload;
- acclimatization;
- direct sun / radiant heat;
- PPE;
- work/rest cycles;
- hydration planning;
- shift timing;
- site risk.

### Manager outputs

- site-level risk;
- peak risk time;
- recommended work/rest pattern;
- supervisor alert;
- compliance log;
- multi-site dashboard.

### Product rule

Do not simply reuse consumer Heat Index wording for occupational safety. Build an explicit work-safety domain layer.

---

# 5. Architecture Evolution Plan

Do not perform a big-bang rewrite.

### Current concern

Large iOS files such as `AppSession.swift` and several large screen files indicate growing coordination debt.

### Gradual decomposition

Split responsibilities over time into:

- AuthSession
- ProfileSession
- LocationSession
- HealthSession
- EntitlementSession
- AppCoordinator

### Domain modules

- Environment
- Forecast
- Risk
- Health
- Profile
- Activity
- Alerts
- Places
- Family
- Premium

### Shared layers

- Networking
- Storage
- Analytics
- Notifications
- Design System
- Accessibility

### Rule

Refactor only when touched by a release. Do not pause product development for a full rewrite.

---

# 6. Canonical Environmental Architecture

```text
DATA SOURCES
weather / air quality / UV / pollen / smoke / dust / official alerts / HealthKit / Health Connect
        ↓
NORMALIZATION
units / timezone / metric mapping / freshness / provenance / quality
        ↓
ENVIRONMENTAL TIME SERIES
current / hourly 48–72h / daily 7d / history
        ↓
PERSONAL CONTEXT
profile / sensitivity / health baseline / recent activity / sleep / symptoms / preferences
        ↓
HIAIR PERSONAL RISK ENGINE
        ↓
ACTION ENGINE
run / walk / cycle / work / ventilate / family / travel
        ↓
DELIVERY
Dashboard / Planner / Alerts / Widgets / Watch / Reports / B2B API
```

### LLM position

LLM/AI is downstream of deterministic facts.

Recommended structured result before explanation:

```json
{
  "overallRisk": "high",
  "heatRisk": "high",
  "airRisk": "moderate",
  "personalLoad": "high",
  "drivers": ["heat_index", "short_sleep", "elevated_resting_hr"],
  "actions": ["postpone_run", "reduce_intensity", "hydrate", "choose_window"]
}
```

AI may convert this into natural language but may not fabricate the source values.

---

# 7. Data Provenance Standard

Every important environmental value or forecast point should support:

- provider/source;
- observed_at;
- issued_at;
- valid_for;
- fetched_at;
- freshness;
- quality/confidence;
- actual / forecast / derived / unavailable classification.

Never silently mix estimated and observed values.

---

# 8. International Product Readiness

## Priority languages

1. English
2. Spanish
3. Arabic + RTL
4. Italian
5. Portuguese
6. French
7. German when justified by market data

### Localization architecture requirement

Backend risk logic should return structured reason/action codes rather than hard-coded Russian/English explanatory strings wherever practical.

### Units

Support regional display preferences:

- °C / °F;
- AQI scale configuration where required;
- local time and DST;
- local date formatting.

---

# 9. Market Release Sequence

The technical roadmap and marketing rollout must stay synchronized.

### Technical readiness order

1. HiAir 1.1 — truth / forecast integrity.
2. HiAir 1.2 — activity Best Time engine.
3. HiAir 1.3 — regional hazards.
4. HiAir 1.4 — predictive alerts.
5. HiAir 1.5 — network/family/travel retention.
6. HiAir 1.6 — adaptive personal intelligence.
7. HiAir 2.0 — Work / B2B.

### Market emphasis

#### USA Sun Belt

Heat + smoke + pollen + activity planning.

#### Southern Europe

Heat + UV + pollen + wildfire + travel.

#### Saudi Arabia / UAE

Heat + humidity + dust + Arabic + later occupational safety.

#### Egypt

Heat + PM2.5 + PM10 + dust + Android + Arabic + regional pricing.

#### Australia

Heat + UV + wildfire/smoke + outdoor sports.

---

# 10. Monetization Rules

## Safety Layer — Free

Keep basic safety information accessible:

- current heat risk;
- current AQ / PM2.5;
- basic alerts;
- basic recommendations;
- basic today windows where trustworthy;
- core privacy controls.

## Personal Intelligence — Premium

Candidates:

- extended personalized planner;
- adaptive personal risk;
- health/wearable intelligence depth;
- advanced insights;
- multi-location;
- family;
- advanced alerts;
- long-term trends;
- AI briefings/reports;
- Protected Days history.

Do not paywall essential safety warnings solely to force subscription conversion.

---

# 11. Release Gates For Every Update

Every release must pass all four gates.

## 1. Product Gate

The release answers a clear user question and does not add decorative complexity without user value.

## 2. Data Integrity Gate

- no fake production data;
- no silent synthetic future values;
- no misleading provenance;
- missing data fails honestly.

## 3. QA Gate

- backend tests;
- API contract tests;
- iOS tests;
- Android tests;
- physical-device QA for critical paths;
- production smoke when backend changes;
- no regression in auth, subscription, privacy or health consent.

## 4. Growth Gate

Each new feature has:

- analytics event coverage;
- target KPI;
- activation/retention/conversion hypothesis;
- measurable success criteria.

---

# 12. Global Definition of Done

HiAir reaches the intended 10/10 product state when:

- environmental current and forecast data are trustworthy and provenance-aware;
- safe windows are based on real forecast points;
- risk is personalized with health/body context;
- activity-specific Best Time recommendations work;
- major regional hazards are supported;
- predictive alerts are actionable and low-noise;
- Saved Places / Family / Travel create retention and network value;
- Personal Adaptation uses baselines and feedback safely;
- international timezone/localization/units are correct;
- consumer and occupational domains are clearly separated;
- mobile architecture remains maintainable;
- Premium monetizes intelligence rather than hiding essential safety;
- Protected Days becomes a meaningful user-value metric;
- marketing claims never exceed what data and validation can support.

---

# 13. Current Next Action

**Active stack branch:** `feat/hiair-1.2-best-time-planner`  

| Release | Status |
|---------|--------|
| 1.1 Forecast Truth | DEPLOYED (`api.hiair.io` `408ec1c3`) — device QA pending |
| 1.2 Best Time Activity Planner | DEPLOYED (`api.hiair.io` `408ec1c3`) — device QA pending |
| 1.3 Multi-Hazard | Dust (PM10) + NO2 live env/hazard scoring DEPLOYED; pollen/smoke open; prod smoke PASS |
| 1.4 Alert Decision Engine | Threshold gate + suppress telemetry + 60min cooldown DEPLOYED (`POST /api/alerts/decide`) |
| 1.5 Saved Places | Backend + family Postgres + Dashboard risk card DEPLOYED; prod smoke PASS |
| 1.6 Personal Adaptation | Baselines → alert sensitivity + planner load (sleep/RHR/HRV) DEPLOYED pending |
| 2.0 Work / B2B Safety | Backend + Settings UI DEPLOYED (`GET /api/work/site-risk`; Heat Index ≠ WBGT) |

Notes:
- `docs/roadmap/HIAIR_1_2_BEST_TIME_ACTIVITY_PLANNER.md`
- `docs/roadmap/HIAIR_1_3_MULTI_HAZARD_NOTES.md`
- `docs/roadmap/HIAIR_1_4_ALERT_DECISION_NOTES.md`
- `docs/roadmap/HIAIR_1_5_SAVED_PLACES_NOTES.md`
- `docs/roadmap/HIAIR_1_6_PERSONAL_ADAPTATION_NOTES.md`
- `docs/roadmap/HIAIR_2_0_WORK_SAFETY_NOTES.md`
- `docs/audit/HIAIR_1_1_FORECAST_TRUTH_QA.md`

No later feature should weaken or bypass the Forecast Truth integrity rules.


---

## Canonical Status

This roadmap is the default HiAir product-development plan from 2026-08-21 onward. It should be updated by versioned replacement or explicit amendment when Sasha approves a major roadmap change.
