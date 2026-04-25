# Phase 2 Blocker Register

Snapshot date: 2026-04-25

| ID | Area | Blocker | Type | Priority | Action | Status |
|---|---|---|---|---|---|---|
| P2-001 | API/Mobile | Mobile clients call ops-gated `/api/observability/*` endpoints | INTERNAL_FIXABLE | P0_CRITICAL | Removed from user-facing mobile clients; documented admin-only policy | FIXED |
| P2-002 | iOS Notifications | APNs permission/registration/device-token upload missing | INTERNAL_FIXABLE | P1_HIGH | Added compile-safe APNs registration flow and backend token upload | FIXED |
| P2-003 | Android Notifications | FCM token handling and Android 13 notification permission strategy missing | INTERNAL_FIXABLE | P1_HIGH | Added permission strategy and local-safe backend token registrar; live FCM remains external | PARTIAL |
| P2-004 | Android Auth | Android onboarding/auth gate is uneven versus iOS | INTERNAL_FIXABLE | P1_HIGH | Protected screens route to Settings/auth when bearer session is missing | PARTIAL |
| P2-005 | iOS Security | Auth token stored in `UserDefaults` | INTERNAL_FIXABLE | P1_HIGH | Moved access token to Keychain with one-time legacy migration | FIXED |
| P2-006 | Android Security | Auth token stored in plain shared preferences | INTERNAL_FIXABLE | P1_HIGH | Stored access token encrypted with Android Keystore-backed AES/GCM | FIXED |
| P2-007 | Backend Smoke | DB/API local smoke blocked by missing Postgres/running API | BLOCKED_BY_ENV | P1_HIGH | Added local smoke runbook, `.env.local.example`, and helper script | BLOCKED_BY_ENV |
| P2-008 | Release | Release manifest partial because iOS IPA missing | BLOCKED_EXTERNAL | P1_HIGH | Added IPA export runbook and ExportOptions template; signed export needs Apple credentials | BLOCKED_EXTERNAL |
| P2-009 | iOS QA | iOS real-device install/QA not verified | NEEDS_MANUAL_QA | P1_HIGH | Run real-device QA after signing access | OPEN |
| P2-010 | Android QA | Android real-device install/QA not verified | NEEDS_MANUAL_QA | P1_HIGH | Run real-device QA and signed artifact check | OPEN |
| P2-011 | Push Live | APNs/FCM live credentials and delivery proof missing | BLOCKED_EXTERNAL | P1_HIGH | Provide credentials and run push E2E checklist | OPEN |
| P2-012 | Apple | Apple Developer account/App Store Connect access missing | BLOCKED_EXTERNAL | P1_HIGH | Owner grants access and signing assets | OPEN |
| P2-013 | Google Play | Google Play Console access/signing upload missing | BLOCKED_EXTERNAL | P1_HIGH | Owner grants access and signing workflow | OPEN |
| P2-014 | Secrets | Production secret manager and rotation evidence missing | BLOCKED_EXTERNAL | P1_HIGH | Configure secure secret storage and rotation owner | OPEN |
| P2-015 | Legal | Privacy Policy, Terms, GDPR controller/contact not signed off | LEGAL_SIGNOFF_REQUIRED | P1_HIGH | Legal review and final URLs/contact details | OPEN |
| P2-016 | Store Privacy | App Store privacy labels and Google Play Data Safety incomplete | LEGAL_SIGNOFF_REQUIRED | P1_HIGH | Complete legal/security review and portal answers | OPEN |
| P2-017 | Payments | Payment provider credentials/E2E not verified if premium enabled | BLOCKED_EXTERNAL | P2_MEDIUM | Keep beta stub or provision provider credentials | OPEN |
| P2-018 | Ops | Ops/on-call owner not confirmed | BLOCKED_EXTERNAL | P1_HIGH | Assign monitored rollout owner | OPEN |
| P2-019 | Deployment | WAF/rate limiting not proven | BLOCKED_EXTERNAL | P2_MEDIUM | Configure deployment-layer protections | OPEN |
