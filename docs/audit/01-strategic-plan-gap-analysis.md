# Strategic Plan Gap Analysis

Snapshot date: 2026-04-25

## Summary

HiAir is a late-MVP / pre-beta project. Backend, iOS, Android, CI, QA, release, and legal scaffolding are present. Closed beta is near-go only after environment/account/legal blockers are accepted or closed. Public launch remains NO-GO.

## Matrix

| Strategic requirement | Source doc | Expected | Current implementation | Status | Gap | Required fix |
|---|---|---|---|---|---|---|
| Research, personas, wellness positioning | `docs/roadmap-from-pdf.md`, `docs/mvp-spec.md` | Persona and wellness/non-medical scope documented | Personas and disclaimers documented | DONE | None material | Keep legal wording aligned |
| MVP backend API | `docs/mvp-spec.md` | Auth, profiles, risk, planner, symptoms, settings, privacy | FastAPI routers and tests present | DONE | DB smoke local env unavailable | Provision Postgres for smoke |
| Environmental data | `docs/roadmap-from-pdf.md` | Mock/live source strategy | Mock and live provider paths exist | PARTIAL | Live keys not verified | Configure provider env and validate |
| Push notifications | `docs/mvp-spec.md` | APNs/FCM E2E | Backend device-token and provider adapters exist | PARTIAL | Mobile registration not wired E2E | Add APNs/FCM app registration and device QA |
| Mobile MVP flows | `docs/mvp-spec.md` | Onboarding, dashboard, planner, symptom log, settings | iOS/Android screens exist; builds now verified | PARTIAL | Android onboarding/auth gating uneven; manual QA needed | Real-device QA and UX pass |
| Subscriptions | `docs/mvp-spec.md` | Out of MVP commercial paywall, beta scaffold acceptable | Backend/mobile technical scaffold exists | PARTIAL | Real billing/provider not verified | Keep stub for beta or provision Stripe |
| Beta prep | `docs/beta-readiness-checklist.md` | Backend smoke, mobile builds, store metadata, QA | Backend tests, Android, iOS simulator verified; metadata draft exists | PARTIAL | DB smoke/API preflight blocked locally; store packet incomplete | Provide env/account proof |
| Public launch | `docs/roadmap-from-pdf.md`, `docs/_operator/go-no-go-verdict.md` | Legal, store, production ops, monitoring, real-device QA | Docs and runbooks present | MISSING | Legal/account/ops external blockers open | Close external blockers |
| Wearables/premium | `docs/roadmap-from-pdf.md` | HealthKit/Health Connect and premium model | Not in MVP; subscription scaffold only | MISSING | Planned later | Post-beta roadmap item |
| Advanced expansion | `docs/roadmap-from-pdf.md` | ML, B2B, smart home, community, i18n | Not implemented | MISSING | Planned later | Post-launch roadmap item |

## Phase status

| Phase | Current status | Verdict |
|---|---|---|
| Phase 1 - Research & Planning | Product scope, personas, wellness positioning, architecture docs exist | DONE |
| Phase 2 - MVP Development | Core backend and mobile flows exist; tests/builds pass after fixes | PARTIAL |
| Phase 3 - Beta Testing & Launch Preparation | CI/docs/checklists exist; mobile simulator/build evidence present | PARTIAL |
| Phase 4 - Public Launch & Growth | Store/legal/ops external gates not closed | MISSING |
| Phase 5 - Wearable & Premium | Explicitly out of MVP except subscription scaffold | MISSING |
| Phase 6 - Advanced Expansion | Not implemented | MISSING |

## Key gaps

- BLOCKED_BY_ENV: local Postgres/API runtime unavailable for DB smoke and HTTP preflight.
- BLOCKED_EXTERNAL: Apple Developer, App Store Connect, Google Play Console, APNs/FCM, production secrets, payment credentials.
- LEGAL_SIGNOFF_REQUIRED: Privacy Policy, Terms, GDPR controller/contact, store privacy labels.
- NEEDS_MANUAL_QA: iOS and Android real-device QA, notification E2E, signed artifacts.
