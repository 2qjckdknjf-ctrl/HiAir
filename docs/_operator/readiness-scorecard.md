# HiAir Readiness Scorecard

Last updated: 2026-04-22  
Scoring model: 0-100 based on verified code/build/tests/docs state (not historical claims only)

## Scores by area

| Area | Score | Explanation | Blockers to next level |
|---|---:|---|---|
| Product readiness | 62 | Core screens/flows exist on both mobile platforms; behavior consistency and contract cohesion still incomplete | Unify auth/navigation behavior, close risk semantic drift, remove hardcoded env assumptions |
| Backend readiness | 86 | FastAPI surface compiles; runtime guardrails enforced; local DB smoke validated; remote backend CI now green with prechecks and smoke flow | Continue contract/privacy hardening and production rollout controls |
| iOS readiness | 74 | Simulator build succeeds; API base URL now centralized via config/env override | Final ATS/store compliance polish and full device QA matrix |
| Android readiness | 74 | Debug/release builds pass; API base URL centralized; cleartext policy split; launcher icon placeholder removed | Release endpoint rollout evidence and QA matrix hardening |
| API/contract readiness | 76 | Auth behavior tightened; risk-level compatibility bridge documented; API-boundary normalization and alias telemetry now implemented | Versioned deprecation/removal rollout and client migration evidence |
| DB/data readiness | 78 | SQL migrations and repositories exist; local DB smoke confirms privacy export/delete and residual-row assertions; type normalization defects fixed | Remote CI evidence and retention matrix proof |
| QA readiness | 89 | Checklists/scripts/tests strengthened; false-green fixed; mobile CI added; local Postgres smoke passes in both open and protected modes; remote CI evidence now captured | Expand device matrix and sustained monitored beta cycle evidence |
| Security/privacy readiness | 85 | Auth/webhook/runtime guardrails enforced; privacy export/delete validated in DB smoke; ops health/observability endpoints protected by admin token policy and CI-backed checks | Final legal alignment and production controls evidence |
| Store readiness | 62 | Metadata packet and last-mile docs exist; external blocker issues now have owner/date/checklists and baseline evidence links | Final platform upload proofs, legal signoff artifacts, and completed compliance evidence |
| Ops readiness | 84 | External blocker control loop is automated (daily update, dashboard refresh, escalation checks, closure/evidence gates) with command-center issue tracking | Final external proof artifacts and sustained execution cadence evidence |
| Public launch readiness | 44 | Foundation is stronger with mobile CI/security/contract/privacy improvements, but high-impact blockers remain | Close remaining critical/high engineering + legal/compliance + store handoff blockers |

## Aggregate interpretation

- Closed beta readiness: **94/100** (conditionally reachable after remaining critical/high closures)
- Store handoff readiness: **62/100** (blocked by external dependencies and final proof artifacts)
- Public launch readiness: **44/100** (not ready)

## External blockers (not engineering-done)

- `EXT-001` App Store Connect access and upload evidence ([#2](https://github.com/2qjckdknjf-ctrl/HiAir/issues/2))
- `EXT-002` Google Play Console access and internal track evidence ([#3](https://github.com/2qjckdknjf-ctrl/HiAir/issues/3))
- `EXT-003` Legal signoff and final policy URLs ([#4](https://github.com/2qjckdknjf-ctrl/HiAir/issues/4))
- `EXT-004` Secrets governance/ownership approval ([#5](https://github.com/2qjckdknjf-ctrl/HiAir/issues/5))
- `EXT-005` Final store metadata/compliance packet evidence ([#6](https://github.com/2qjckdknjf-ctrl/HiAir/issues/6))

## Score improvement path (next target levels)

- Target 75+: close all critical/high security/contract/build blockers and enforce CI gates
- Target 85+: complete store packet, legal alignment, device QA matrix, and release reproducibility evidence
- Target 90+: complete incident/ops hardening and successful closed-beta cycle with no P0/P1 regressions
