# HiAir — Final Release Program Status

**Updated:** 2026-07-21 (Health Intelligence release certification)  
**Branch:** `main` @ `28696b0`  
**Production SHA:** `28696b020aa1a0e7c895e2e17a0b95431dac1690`  
**Health Intelligence:** PRODUCTION LIVE + synthetic smoke PASS; **device HealthKit/HC E2E NOT VERIFIED**  
**TestFlight:** build **103** VALID (`dce5426e-14b0-4fb1-bbf4-0c04648afaa2`) → «Первый»  
**Verdict:** **PRODUCTION DEPLOYED — WAITING FOR DEVICE HEALTH DATA**

---

## Engineering closed

| Area | Status | Evidence |
|------|--------|----------|
| Production API | LIVE | health 200; SHA `28696b0` |
| Health Intelligence merge | MERGED | PR #30 `6eae02a` + follow-ups |
| Health routes unauth | LIVE | summary/sync/data **401** |
| Synthetic auth health smoke | PASS | 14-day sync, insights 7/30, delete, privacy |
| Live AI | PASS | `current-risk` llm; post-deploy smoke |
| Backend pytest + final gate | PASS | local full suite + prior gate |
| iOS build 103 | DISTRIBUTED | TestFlight VALID + internal testers |
| Android signed release | PASS | v2 signed; API `https://api.hiair.io` |

## Operator / device certification required

| Area | Status | Owner action |
|------|--------|--------------|
| iPhone HealthKit E2E | NOT RUN | TF **103** checklist in `REAL_DEVICE_QA_REPORT.md` |
| Android Health Connect E2E | NOT RUN | Physical device + signed APK |
| StoreKit sandbox purchase | NOT RUN | Retest on TF 103 |
| Play Billing E2E | EXTERNALLY BLOCKED | No Play Console app for `com.hiair` |
| Accessibility device audit | NOT RUN | Dynamic Type / VoiceOver / Dark Mode |

## Release configuration

| Build | API base |
|-------|----------|
| Android debug | `http://10.0.2.2:8000` |
| Android release | `https://api.hiair.io` |
| iOS debug | `http://127.0.0.1:8000` |
| iOS release / TestFlight | `https://api.hiair.io` |

## Key commits

- `6eae02a` — Merge PR #30 Health Intelligence 100
- `7dcad23` — fix: 7-day insights window + prod smoke harness; iOS build bump
- `28696b0` — fix: consentActive on insights; Android keystore root; iOS build **103**

See `docs/release/qa/REAL_DEVICE_QA_REPORT.md` and `docs/audit/HEALTH_INTELLIGENCE_100_SPRINT_REPORT.md`.
