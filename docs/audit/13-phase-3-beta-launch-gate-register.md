# Phase 3 Beta Launch Gate Register

Snapshot date: 2026-04-25

| ID | Gate | Current status | Required proof | Owner | Can execute locally | Status |
| -- | ---- | -------------- | -------------- | ----- | ------------------- | ------ |
| G3-001 | backend DB smoke | BLOCKED_BY_ENV: Postgres connection refused | `smoke_db_flow.py` passes against initialized Postgres | Backend/Ops | Yes, with Postgres | BLOCKED_BY_ENV |
| G3-002 | backend API preflight | BLOCKED_BY_ENV: API server not running | `beta_preflight.py` passes against running API | Backend/Ops | Yes, with API + DB | BLOCKED_BY_ENV |
| G3-003 | retention dry-run | BLOCKED_BY_ENV: Postgres connection refused | `retention_cleanup.py --dry-run` passes | Backend/Ops | Yes, with Postgres | BLOCKED_BY_ENV |
| G3-004 | env security strict | DONE with `.env.local.example`; unmanaged local shell still missing env | `check_env_security.py --strict` passes with beta env | Backend/Ops | Yes | DONE |
| G3-005 | iOS real-device QA | NOT_VERIFIED | Completed real-device QA script | Mobile QA | No, needs device/signing | NEEDS_MANUAL_QA |
| G3-006 | iOS archive | BLOCKED_EXTERNAL | Release archive succeeds with signing | iOS/Release owner | No, needs Apple signing | BLOCKED_EXTERNAL |
| G3-007 | iOS IPA export | BLOCKED_EXTERNAL | Exported IPA artifact | iOS/Release owner | No, needs Apple signing | BLOCKED_EXTERNAL |
| G3-008 | TestFlight upload | BLOCKED_EXTERNAL | Build visible in App Store Connect/TestFlight | Release owner | No | BLOCKED_EXTERNAL |
| G3-009 | Android real-device QA | NOT_VERIFIED | Completed real-device QA script | Mobile QA | No, needs device | NEEDS_MANUAL_QA |
| G3-010 | Android signed AAB | PARTIAL: `bundleRelease` generated AAB; Play signing decision still external | Signed release AAB or Play App Signing proof | Android/Release owner | Partially | PARTIAL |
| G3-011 | Google Play Internal upload | BLOCKED_EXTERNAL | Internal testing release created | Release owner | No | BLOCKED_EXTERNAL |
| G3-012 | iOS APNs token registration | NEAR-GO | Physical-device token uploaded to backend | iOS/Ops | No, needs device/APNs | NEEDS_MANUAL_QA |
| G3-013 | Android FCM token generation | PARTIAL | FCM token generated and uploaded | Android/Ops | No, needs Firebase config | BLOCKED_EXTERNAL |
| G3-014 | push live delivery | BLOCKED_EXTERNAL | Delivered notification + backend delivery attempt | Mobile/Ops | No, needs APNs/FCM credentials | BLOCKED_EXTERNAL |
| G3-015 | store metadata | PARTIAL | Completed metadata packet, no TBDs except signed external refs | Product/Release | Partially | READY_FOR_OWNER |
| G3-016 | privacy labels | LEGAL_SIGNOFF_REQUIRED | Approved App Store privacy labels | Legal/Security | No | LEGAL_SIGNOFF_REQUIRED |
| G3-017 | Google Play Data Safety | LEGAL_SIGNOFF_REQUIRED | Approved Play Data Safety answers | Legal/Security | No | LEGAL_SIGNOFF_REQUIRED |
| G3-018 | legal signoff | LEGAL_SIGNOFF_REQUIRED | Privacy/Terms/GDPR controller signed off | Legal | No | LEGAL_SIGNOFF_REQUIRED |
| G3-019 | ops/on-call owner | BLOCKED_EXTERNAL | Named beta owner/on-call/support contact | Project owner | No | BLOCKED_EXTERNAL |
| G3-020 | deployment WAF/rate limiting | BLOCKED_EXTERNAL | Deployment-layer rate limit/WAF proof | Infra/Ops | No | BLOCKED_EXTERNAL |
