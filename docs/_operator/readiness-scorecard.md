# HiAir Readiness Scorecard

Last updated: 2026-04-18  
Scoring model: 0-100 based on verified code/build/tests/docs state (not historical claims only)

## Scores by area

| Area | Score | Explanation | Blockers to next level |
|---|---:|---|---|
| Product readiness | 62 | Core screens/flows exist on both mobile platforms; behavior consistency and contract cohesion still incomplete | Unify auth/navigation behavior, close risk semantic drift, remove hardcoded env assumptions |
| Backend readiness | 82 | FastAPI surface compiles; runtime guardrails enforced; local DB smoke uncovered and resolved real bytes/serialization defects | Collect remote CI evidence and continue contract/privacy hardening |
| iOS readiness | 74 | Simulator build succeeds; API base URL now centralized via config/env override | Final ATS/store compliance polish and full device QA matrix |
| Android readiness | 74 | Debug/release builds pass; API base URL centralized; cleartext policy split; launcher icon placeholder removed | Release endpoint rollout evidence and QA matrix hardening |
| API/contract readiness | 76 | Auth behavior tightened; risk-level compatibility bridge documented; API-boundary normalization and alias telemetry now implemented | Versioned deprecation/removal rollout and client migration evidence |
| DB/data readiness | 78 | SQL migrations and repositories exist; local DB smoke confirms privacy export/delete and residual-row assertions; type normalization defects fixed | Remote CI evidence and retention matrix proof |
| QA readiness | 85 | Checklists/scripts/tests strengthened; false-green fixed; mobile CI added; local Postgres smoke passes in both open and protected modes; retention evidence export now machine-readable | Remote CI evidence for new workflows remains |
| Security/privacy readiness | 83 | Auth/webhook/runtime guardrails enforced; privacy export/delete validated in DB smoke; ops health/observability endpoints protected by admin token policy | Remote CI evidence and final legal alignment |
| Store readiness | 58 | Build artifacts/runbooks exist, Android icon blocker reduced, legal drafts aligned, and metadata packet draft prepared | Final legal signoff, account access, and platform-specific final compliance answers |
| Ops readiness | 74 | Retention/handover + incident runbooks now documented; retention matrix and JSON evidence artifacts available; ops endpoints protected by admin token policy | Monitored rollout evidence and on-call ownership signoff |
| Public launch readiness | 44 | Foundation is stronger with mobile CI/security/contract/privacy improvements, but high-impact blockers remain | Close remaining critical/high engineering + legal/compliance + store handoff blockers |

## Aggregate interpretation

- Closed beta readiness: **91/100** (conditionally reachable after remaining critical/high closures)
- Store handoff readiness: **40/100** (blocked by engineering + external dependencies)
- Public launch readiness: **44/100** (not ready)

## External blockers (not engineering-done)

- Apple Developer / App Store Connect access for upload and distribution
- Google Play Console access for internal/public tracks
- Legal approval and final wording for privacy policy and terms of service
- Potential push provider production credentials and secret governance confirmation

## Score improvement path (next target levels)

- Target 75+: close all critical/high security/contract/build blockers and enforce CI gates
- Target 85+: complete store packet, legal alignment, device QA matrix, and release reproducibility evidence
- Target 90+: complete incident/ops hardening and successful closed-beta cycle with no P0/P1 regressions
