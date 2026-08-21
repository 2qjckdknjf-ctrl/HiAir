# HiAir 1.1 — Forecast Truth

## Purpose

This document is the implementation prompt / technical specification for the **HiAir 1.1 — Forecast Truth** release.

Baseline: current `main` release line corresponding to the submitted iOS 1.0 / build-188 release candidate. Do **not** rewrite the application. Preserve working Auth, Onboarding, Dashboard, HealthKit, Health Intelligence, Symptoms, Insights, Premium/StoreKit, AI reports, privacy, and existing production API behavior unless this specification explicitly requires a compatibility change.

Work only on branch:

`feat/hiair-1.1-forecast-truth`

Never commit implementation work directly to `main`.

---

# 1. Product Objective

HiAir 1.1 must make every future-facing environmental recommendation truthful.

Today the product already has a strong personal/health intelligence layer, but production day planning and safe-window logic may project future hours from the current environmental snapshot using deterministic mathematical curves. In addition, some displayed environmental metrics can be derived heuristically instead of coming from a real provider.

The release objective is:

> If HiAir says that a future hour is safer or riskier, that conclusion must be computed from a real timestamped forecast point or be explicitly marked unavailable. No silent synthetic future values are allowed in production.

The core user questions that 1.1 must answer reliably:

1. Is it safe for me to go outside now?
2. When will conditions improve today?
3. What is the safest window today?
4. When should I ventilate my home?
5. How trustworthy/fresh are the underlying data?

---

# 2. Non-Goals

Do NOT add the following in 1.1:

- pollen;
- wildfire/smoke mapping;
- dust/sandstorm module;
- family profiles;
- travel mode;
- WBGT / HiAir Work;
- new generic AI chat;
- new HealthKit features;
- new symptom taxonomy;
- redesign of the complete UI;
- large-scale AppSession rewrite;
- microservice split.

These are later releases.

---

# 3. Hard Product Integrity Rules

These are release blockers.

1. **No synthetic future forecast in production.**
2. **No fake current data in protected environments.** Existing production fail-closed/sample rules must remain intact.
3. A field must never be presented as measured/forecast if it was merely inferred from another unrelated metric.
4. Every environmental forecast point must have provenance and timestamp metadata.
5. Missing provider data must remain `null`/unavailable unless a scientifically defensible derived metric is explicitly modeled and marked `derived`.
6. The LLM may explain risk; it must not invent or calculate forecast safety decisions.
7. HealthKit and health data behavior must remain wellness-only, consent-bound, privacy-safe, and functionally optional.
8. Existing store purchase verification must remain fail-closed.

---

# 4. Existing Code To Audit Before Editing

Read these first and document the current behavior before implementation:

Backend:

- `backend/app/services/air_environment_service.py`
- `backend/app/services/environment_service.py`
- `backend/app/services/air_risk_engine.py`
- `backend/app/api/air.py`
- planner/dashboard related APIs/services
- current provider configuration in settings/env
- tests around environment, risk, dashboard and planner

Also search for:

- `_project_environment`
- `_shift_env`
- hardcoded UV derivation
- hardcoded PM10 derivation
- hardcoded wind derivation
- `safeWindows`
- `hourlyRisk`

Mobile iOS:

- `mobile/ios/HiAir/Screens/DashboardView.swift`
- `mobile/ios/HiAir/Screens/DailyPlannerView.swift`
- `mobile/ios/HiAir/Networking/APIClient.swift`
- environmental / air / planner DTOs
- localization keys

Android:

- dashboard ViewModel/renderer
- planner ViewModel/renderer
- API models/networking
- environmental models

Governance:

- `AGENTS.md`
- production env / release scripts
- `scripts/release/hiair_final_gate.sh`
- current audit/release docs

Do not assume old docs are accurate when code disagrees. Code + production contracts are the source of truth.

---

# 5. Target Backend Architecture

Implement a normalized environmental forecast domain with provider abstraction.

Recommended conceptual pipeline:

```text
Weather Provider Adapter(s)
Air Quality Provider Adapter(s)
        ↓
Normalization Layer
        ↓
Environmental Forecast Model
        ↓
Quality / Provenance / Freshness
        ↓
Risk Engine
        ↓
Planner / Safe Windows / Dashboard
        ↓
AI explanation only
```

The risk engine must not know provider-specific JSON structures.

---

# 6. Canonical Models

Introduce canonical typed models. Names may follow the repository's existing conventions, but semantics must match.

## 6.1 EnvironmentalDataKind

Allowed semantics:

- `observed`
- `forecast`
- `derived`
- `cached`

Do not use `derived` to disguise unavailable provider data.

## 6.2 EnvironmentalMetricSource

At minimum:

- provider name;
- provider product/feed where applicable;
- `observed_at` or `forecast_for`;
- `issued_at` if provider supplies it;
- `fetched_at`;
- data kind;
- cache age/freshness state.

## 6.3 EnvironmentalForecastPoint

Required core fields:

- `timestamp`
- `timezone`
- `lat`
- `lon`
- `temperature_c`
- `apparent_temperature_c`
- `relative_humidity_pct`
- `dew_point_c` when available
- `wind_speed_mps`
- `wind_gust_mps` when available
- `uv_index`
- `aqi`
- `pm25_ugm3`
- `pm10_ugm3`
- `ozone` using one canonical internal unit
- optional `no2` if provider already exposes it without scope expansion
- provenance/source metadata
- quality/freshness state

Fields that the provider cannot supply must be nullable.

## 6.4 EnvironmentalForecast

Required:

- `current`
- `hourly` forecast: minimum 24h, target 48h
- optional `daily` 7-day block if low-cost to source cleanly
- location metadata
- timezone
- generated/fetched timestamps
- provider summary

For 1.1 the hard requirement is trustworthy current + hourly data.

---

# 7. Provider Strategy

Preserve existing provider configuration and make it more explicit rather than hardcoding a single vendor.

Implement provider interfaces/protocols such as:

```python
class WeatherForecastProvider(Protocol):
    async def get_current(...): ...
    async def get_hourly(...): ...

class AirQualityForecastProvider(Protocol):
    async def get_current(...): ...
    async def get_hourly(...): ...
```

Use the currently supported provider stack where practical. Open-Meteo may remain a no-key/default option if it satisfies the needed fields and availability. Existing OpenWeather/WAQI adapters should remain usable when configured.

Important: if an AQ provider does not provide real hourly pollutant forecast, do not fabricate it. Use another configured provider if available or return partial forecast semantics.

Provider adapter responsibilities:

- call provider;
- validate response;
- normalize units;
- convert timestamps correctly;
- attach source metadata;
- never contain personalized risk logic.

---

# 8. Timezone Correctness

This is a P0 requirement.

All forecast timestamps and safe windows must be built using the forecast location timezone, not server UTC arithmetic presented as local time.

Requirements:

1. Resolve provider timezone or location timezone reliably.
2. Store/transport unambiguous ISO-8601 timestamps with offsets where possible.
3. Preserve timezone identifier in responses.
4. Safe window boundaries must reflect the local forecast timeline.
5. Test at least:
   - Barcelona / Europe-Madrid-like timezone;
   - Phoenix / America-Phoenix;
   - New York DST behavior;
   - Dubai / Asia-Dubai;
   - Riyadh / Asia-Riyadh;
   - Cairo / Africa-Cairo.
6. Add DST boundary tests.

Do not patch timezone formatting only in the UI; the backend temporal model must be correct.

---

# 9. Remove Synthetic Forecast Logic

Search all production code for future projection based on the current snapshot.

Known categories to remove/disable from production planner path:

- sinusoidal temperature projection;
- sinusoidal humidity projection;
- traffic-wave AQI projection;
- synthetic PM2.5/ozone changes;
- any `_project_environment` / `_shift_env` logic that manufactures hourly weather/air values.

You may retain deterministic generators only inside tests/fixtures with explicit test naming.

The planner must consume actual `EnvironmentalForecastPoint[]`.

If hourly forecast is unavailable:

- planner must return an honest partial/unavailable state;
- do not silently fall back to synthetic hourly values;
- current-risk may still work from valid current data.

---

# 10. Real UV / PM10 / Wind Semantics

Eliminate silent heuristics such as:

- PM10 = PM2.5 × constant;
- UV inferred from temperature;
- wind inferred from humidity.

Rules:

- Prefer direct provider values.
- If provider does not expose a metric, return `null`.
- If a scientifically valid derived metric is intentionally added later, it must include `kind=derived`, method/version, and tests.
- UI must gracefully render unavailable metrics.

Do not break the current dashboard because one optional metric is missing.

---

# 11. Risk Engine Integration

Do not rewrite the entire risk engine.

Refactor its inputs so it can evaluate a real forecast point using the same personalized context currently used for current risk.

Required behavior:

```text
for point in hourly_forecast:
    risk = evaluate_risk(profile, point, personal_load_context)
```

Personal load/HealthKit context must not be falsely extrapolated hour by hour as though future physiology were known. For 1.1 use current/latest validated personal-load context according to existing product semantics and make this explicit in code comments/contracts.

Do not have the LLM create thresholds or alter risk output.

---

# 12. Safe Window Engine

Build safe windows from consecutive real forecast points.

For each supported window type currently in production:

- walk / general outdoor;
- run/sport where existing contract supports it;
- ventilation.

Algorithm requirements:

1. evaluate each hourly point;
2. classify allowed/not allowed according to current rules;
3. merge consecutive acceptable intervals;
4. preserve local timestamps;
5. attach confidence/data-quality based on provider completeness/freshness;
6. reject windows based on stale or invalid forecast data when appropriate.

The existing API response shape should remain backward compatible where possible.

Do not invent minute-level precision if source data are hourly. If windows are hourly, communicate that honestly.

---

# 13. API Contracts

Preserve existing mobile calls where practical to minimize risk.

## Required existing behavior

- `/api/air/current-risk` continues to work.
- `/api/air/day-plan` / existing equivalent planner endpoint continues to work.
- Dashboard overview routes continue to work.
- Premium entitlement gating remains unchanged.

## Additive fields are allowed

Recommended additions:

- forecast `generatedAt`
- `timezone`
- `dataQuality`
- `freshness`
- `sources`
- per-point or per-metric provenance if payload size stays reasonable

If introducing a new forecast endpoint, prefer an additive endpoint such as:

`GET /api/air/forecast?profileId=...&hours=48`

but do not require the mobile clients to migrate unnecessarily if the existing planner API can evolve safely.

Update OpenAPI models and contract tests.

---

# 14. Caching / Reliability

Maintain the existing live → cached behavior, but make forecast cache semantics explicit.

Recommended rules:

- geo-keyed cache;
- short TTL appropriate to forecast freshness;
- separate current and forecast cache keys if needed;
- record source fetch time;
- cached data must be labeled cached;
- stale-while-revalidate is acceptable only if stale age is visible internally and within policy;
- protected production must never degrade to sample/mock forecast.

A temporary provider outage should not crash the app.

Return partial data where safe and explicit.

---

# 15. iOS Changes

Keep 1.1 visually conservative.

## Dashboard

Preserve current layout and HealthKit/AI behavior.

Add only what is necessary:

- honest freshness label based on backend metadata instead of always implying fresh;
- optional source/data info sheet;
- graceful unavailable state for UV/PM10/wind when missing.

Do not redesign the dashboard.

## Daily Planner

Keep existing screen structure, but ensure displayed hourly risk and safe windows come from real forecast points.

Add:

- forecast last-updated label;
- timezone-safe rendering;
- data unavailable/partial state;
- no misleading forecast when hourly data are absent.

Do not add Activity Planner 2.0 yet; that is HiAir 1.2.

## DTOs

Extend decoding safely:

- new optional metadata fields;
- backwards-compatible defaults only where semantically truthful;
- no client-generated environmental fallback.

---

# 16. Android Parity

HiAir 1.1 should not create a permanent data-contract divergence.

Android requirements:

- consume the same backend planner/current contracts;
- render real hourly risk;
- render safe windows with correct local time;
- handle missing optional metrics;
- show freshness/partial state where appropriate;
- no client synthetic forecast.

Do not block iOS release on unrelated Android Play billing status, but keep code/API parity and CI green.

---

# 17. Localization

Use existing localization architecture.

Add keys, not hardcoded user-facing strings.

At minimum cover the languages currently shipped by the app:

- Russian
- English
- Spanish
- Italian
- French

Required concepts:

- forecast updated;
- data partially available;
- forecast unavailable;
- source/provider;
- cached/stale wording;
- metric unavailable.

Do not put localized sentences inside backend risk calculation logic when reason codes can be returned instead.

---

# 18. Observability / Analytics

Add privacy-safe telemetry. No health values, coordinates, email, tokens, or PII in analytics events.

Suggested events:

- `forecast_fetch_started`
- `forecast_fetch_succeeded`
- `forecast_fetch_failed`
- `forecast_cache_used`
- `forecast_partial_data`
- `planner_real_forecast_loaded`
- `planner_forecast_unavailable`

Properties may include only safe categorical metadata such as:

- provider name;
- hours returned;
- freshness bucket;
- missing metric names;
- HTTP/error category;
- cache hit yes/no.

Add backend structured logs for provider latency and completeness.

---

# 19. Security / Privacy

Must preserve all current guarantees.

- No secrets in repository.
- Provider keys only through environment/secrets.
- Never log precise user health values.
- Avoid logging precise user coordinates in product analytics.
- Existing auth scopes remain enforced.
- Forecast endpoints that need personalized profile risk remain authenticated as currently designed.
- Public environment endpoints, if any, must not leak user profile data.
- HealthKit data stays optional and consent-bound.

---

# 20. Tests

## Backend unit tests

Add deterministic fixtures for provider payloads.

Test:

- provider normalization;
- units;
- null/missing metrics;
- provenance;
- freshness;
- timezone conversion;
- DST;
- cache semantics;
- provider failure;
- partial provider response;
- production no-sample behavior;
- safe-window merging from hourly forecast;
- risk calculation over forecast points;
- synthetic projection absent from production path.

## Contract/API tests

Verify:

- current-risk compatibility;
- day-plan compatibility;
- 24/48 hourly ordering;
- local timestamps;
- Premium gates unchanged;
- old clients tolerate additive response fields;
- source metadata serializes correctly.

## iOS tests

Add/extend:

- forecast DTO decoding;
- optional metric decoding;
- timezone-safe window formatting;
- partial/unavailable planner UI state;
- freshness labels;
- existing HealthKit/StoreKit suites remain green.

## Android tests

Add equivalent DTO/state tests.

## Regression

Run the full relevant suite; do not only run new tests.

---

# 21. Accuracy Verification Fixture Set

Create a stable test fixture matrix representing target markets:

1. Barcelona — hot/humid summer day.
2. Phoenix — extreme dry heat.
3. Miami — heat + high humidity.
4. Dubai — extreme heat + humidity.
5. Riyadh — extreme dry heat.
6. Cairo — heat + particulate load.

These do not need live network calls in unit tests. Use recorded/sanitized provider fixtures with known timestamps.

Validate that:

- forecast points remain chronologically correct;
- safe windows are deterministic for a fixed fixture;
- different climates produce meaningfully different risk periods;
- no city inherits server timezone.

---

# 22. Migration Strategy

Prefer no database migration unless forecast persistence/history truly requires it.

For 1.1, cache/in-memory/Redis-like existing storage may be sufficient if consistent with current infrastructure.

If adding a SQL migration:

- make it additive;
- include rollback;
- include RLS/security if user-linked;
- add migration tests;
- do not store unnecessary high-volume third-party raw payloads.

Do not introduce a new database solely to ship 1.1.

---

# 23. Implementation Stages / Commit Plan

Execute in this order. Keep commits reviewable.

## Commit 1 — Audit and contracts

Suggested message:

`docs(forecast): document 1.1 data integrity contract`

Tasks:

- map all synthetic forecast paths;
- map provider capabilities;
- document old/new API contracts;
- add failing contract tests where useful.

Do not change user behavior yet.

## Commit 2 — Provider forecast abstraction

Suggested message:

`feat(backend): add normalized environmental forecast providers`

Tasks:

- canonical models;
- weather hourly adapter;
- air hourly adapter;
- unit normalization;
- provenance;
- timezone metadata;
- provider fixtures/tests.

## Commit 3 — Forecast cache and quality semantics

Suggested message:

`feat(backend): add forecast freshness and quality handling`

Tasks:

- cache;
- freshness;
- partial response support;
- no production sample fallback.

## Commit 4 — Real planner/safe windows

Suggested message:

`fix(backend): replace synthetic planner projections with real forecast`

Tasks:

- remove production use of synthetic projection;
- risk-evaluate real hourly points;
- safe-window grouping;
- ventilation windows;
- compatibility response.

This is the core release commit.

## Commit 5 — Truthful environmental metrics

Suggested message:

`fix(backend): remove heuristic UV PM10 and wind values`

Tasks:

- direct provider values;
- null semantics;
- tests preventing reintroduction of heuristic values.

## Commit 6 — iOS integration

Suggested message:

`feat(ios): surface real forecast freshness and partial states`

Tasks:

- DTOs;
- planner;
- dashboard freshness;
- localization;
- tests.

No large visual redesign.

## Commit 7 — Android parity

Suggested message:

`feat(android): align planner with Forecast Truth contracts`

## Commit 8 — Release hardening

Suggested message:

`test(release): certify HiAir 1.1 forecast integrity`

Tasks:

- full tests;
- static searches for forbidden synthetic production helpers;
- regression QA docs;
- production smoke tooling;
- update source-of-truth docs.

---

# 24. Static Release Guard

Add a guard/check that prevents accidental return of production synthetic future data.

The exact implementation may vary, but the release gate should fail if known test-only forecast generator code is imported/referenced by production planner routes.

Also add regression assertions that production protected environment does not return:

- sample future hourly forecast;
- silently derived UV from temperature;
- silently derived PM10 from PM2.5 constant;
- wind synthesized from humidity.

---

# 25. QA / TestFlight Gate

Do not claim 1.1 production-ready from simulator tests alone.

Before release candidate approval perform physical-device validation on a new TestFlight build.

Minimum physical matrix:

1. first launch / auth / onboarding regression;
2. location allowed;
3. location denied then re-enabled;
4. Dashboard real current risk;
5. Planner shows real hourly periods;
6. local timezone labels correct;
7. pull-to-refresh updates freshness;
8. provider partial/unavailable behavior does not crash;
9. HealthKit connected state still works;
10. HealthKit denied still leaves app functional;
11. Premium planner entitlement still works;
12. monthly/yearly paywall is not regressed;
13. logout/login/account switch regression;
14. privacy/export/delete regression.

Where possible compare several displayed forecast points with the raw provider response used by backend and record evidence.

---

# 26. Production Smoke Gate

After backend deployment to `https://api.hiair.io`, run authenticated smoke with a real profile/location.

Verify:

- current endpoint returns live/cached truthful source metadata;
- day planner returns ordered hourly points;
- safe windows are based on the same timestamps;
- timezone matches location;
- no `sample`/`mock` source in protected production;
- missing metrics are null/unavailable rather than fabricated;
- old mobile contracts are not broken.

Do not promote the iOS release until backend smoke passes.

---

# 27. Definition of Done

HiAir 1.1 Forecast Truth is DONE only if all are true:

- [ ] real hourly weather forecast is used in production planner;
- [ ] real hourly air data/forecast is used when available and missing data are explicit;
- [ ] production synthetic future projection is removed from planner/safe windows;
- [ ] UV is direct-provider or unavailable;
- [ ] PM10 is direct-provider or unavailable;
- [ ] wind is direct-provider or unavailable;
- [ ] forecast provenance exists;
- [ ] freshness exists;
- [ ] timezone is location-correct;
- [ ] DST tests pass;
- [ ] safe windows are derived from actual forecast points;
- [ ] Dashboard remains functional;
- [ ] Planner remains Premium-gated exactly as intended;
- [ ] HealthKit functionality is not regressed;
- [ ] subscriptions are not regressed;
- [ ] iOS and Android compile/tests pass;
- [ ] backend full relevant suite passes;
- [ ] production smoke on api.hiair.io passes;
- [ ] new TestFlight physical QA passes;
- [ ] no fake/sample production forecast;
- [ ] source-of-truth docs updated.

---

# 28. Stop Conditions

Stop implementation and report a blocker rather than hiding it if:

- no configured provider can supply trustworthy future environmental data required for a feature;
- provider licensing forbids the intended use;
- a required production credential is unavailable;
- new API behavior would break the released 1.0 client and cannot be made backward compatible;
- forecast source quality is insufficient to make a safe-window claim.

When blocked, preserve the current truthful feature and return unavailable/partial rather than creating a fake fallback.

---

# 29. Final Agent Instruction

Work autonomously on `feat/hiair-1.1-forecast-truth`.

Start with a truth audit of the actual current code. Then implement stage by stage, test after each stage, and continue until all code-level gates are green or a genuine external blocker exists.

Do not ask for confirmation between normal implementation stages.

Do not merge to `main`.

At completion provide one final report containing:

1. exact branch + HEAD SHA;
2. commits created;
3. files changed;
4. old synthetic paths removed;
5. providers and fields now used;
6. tests run and exact results;
7. iOS/Android build status;
8. production deploy status;
9. TestFlight/device QA status;
10. remaining blockers;
11. one honest verdict from:
   - `CODE COMPLETE — WAITING FOR PRODUCTION/DEVICE QA`
   - `RELEASE CANDIDATE — PHYSICAL QA REQUIRED`
   - `HIAIR 1.1 FORECAST TRUTH READY`
   - `BLOCKED`

Never claim the final READY verdict without production smoke and physical-device evidence.
