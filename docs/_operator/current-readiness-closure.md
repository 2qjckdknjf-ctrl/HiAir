# HiAir Current Readiness Closure (Interim)

Last updated: 2026-04-18

## What is now evidence-verified

- Backend compile and tests are green (`24 passed`).
- Android debug/release build and lint are green.
- iOS simulator build is green.
- CI hardening includes backend pytest and separate Android/iOS workflow files.
- Runtime security guardrails are enforced for protected environments.
- Local Postgres end-to-end smoke flow passes, including:
  - auth/profile/subscription/notifications flows
  - privacy export and delete-account flow
  - residual personal-data DB assertions after deletion

## Newly discovered and fixed defects during operator run

1. password hash verification failed on bytes payloads (fixed + tests)
2. subscription repository status/plan parsing failed on bytes payloads (fixed + tests)
3. privacy export query failed on `text = bytea` edge case (fixed + tests)

## Remaining internal blockers

- Versioned deprecation/removal execution for `medium` vs `moderate` aliases.
- Full store metadata packet finalization.
- Ops on-call owner confirmation and monitored rollout evidence.

## External blockers (cannot be auto-closed in code)

- Apple App Store Connect credentials and upload access.
- Google Play Console credentials and upload access.
- Legal final signoff for privacy policy and terms.
- Production secrets governance/ownership signoff.
- Remote CI evidence cannot be produced until branch changes are committed/pushed
  (resolved on current branch: Android/iOS/Backend workflow evidence captured).

## Interim go/no-go

- Closed beta: **near go**, pending remaining internal blockers and external access readiness.
- Store handoff: **not yet go**, pending metadata/legal/account dependencies.
- Public launch: **no-go** until legal/store/ops closure.
