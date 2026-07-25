# HiAir — Final Release Program Status

**Updated:** 2026-07-25 (PR #34 Runtime UX Recovery merged)  
**Branch:** `main` @ `cda6722`  
**Production API SHA:** `02439521f3c56eb7ebe0fe6119d0be2179138293` (unchanged by this PR)  
**TestFlight:** build **127** VALID (`3fc99d09-b232-4bce-a7a1-1f72449f9bbb`) → «Первый» (`IN_BETA_TESTING`)  
**Verdict:** **CODE FIXED — WAITING FOR PHYSICAL RETEST**

---

## Engineering closed (PR #34)

| Area | Status | Evidence |
|------|--------|----------|
| PR #34 merge | MERGED | `cda6722` |
| Health sync coordinator | FIXED | all entry points → `startBackgroundHealthSync` |
| Revoke/delete local-first | FIXED | consent cleared before remote await |
| Premium rollback attribution | FIXED | `userId` required on rollback notifications |
| Fresh CI on merge head | PASS | ios-build + Security + Xcode Cloud Archive |
| Backend redeploy | NOT REQUIRED | no backend delta; health SHA `0243952` |

## Operator / device certification required

| Area | Status | Owner action |
|------|--------|--------------|
| iPhone Runtime UX matrix (TF 127) | NOT RUN | city / Health / revoke / Premium timings |
| Android physical E2E | NOT RUN | device + signed APK |
| StoreKit sandbox purchase | NOT RUN | retest on TF 127 |
| Play Billing E2E | EXTERNALLY BLOCKED | No Play Console app for `com.hiair` |

## Release configuration

| Build | API base |
|-------|----------|
| Android debug | `http://10.0.2.2:8000` |
| Android release | `https://api.hiair.io` |
| iOS debug | `http://127.0.0.1:8000` |
| iOS release / TestFlight | `https://api.hiair.io` |

See `docs/audit/P0_RUNTIME_UX_RECOVERY.md` and `docs/release/qa/REAL_DEVICE_QA_REPORT.md`.
