# HiAir deep delta audit (changes vs default branch + regressions + remaining)

Snapshot: **2026-04-26**  
Base for “what landed since integration branch”: `origin/cursor/bootstrap-ci-and-tooling..HEAD` (current branch `cursor/risk-alias-store-gates`).

## 1) What changed (code / doc / config)

| Area | Summary | Evidence |
| --- | --- | --- |
| CI / gates | External blocker workflows, strict gates, exit-code fixes | `git log`: `e85e7de`, `017f06d`, `4ac17fa`, `705d02c` |
| Risk / store | Risk-alias deprecation controls, store packet gates | `c09fd46` |
| Runtime / RC | Closed beta runtime gates, RC1 package, agent memory | `e79662a`, `002e9fe`, `1070974`, `6db46cd` |
| iOS | Push entitlement, IPA export readiness markers | `1477fd6`, `0b17246` |
| Mobile L10n | Multilingual flows and remaining copy | `25b43f1`, `a5ca1e6` |
| Android | Removed unused strict request helper | `e5c479a` |
| Phase 18 (this pass) | Push diagnostics (OSLog / `HiAirPush`), `--rc` manifest footer | `18-execution-ledger.md`; code diff |

## 2) What was fixed earlier and still holds

| Claim | Verification (this session) | Status |
| --- | --- | --- |
| Local Postgres smoke path | `run_local_beta_smoke.sh` completed migrations, `smoke_db_flow`, retention, env strict, historical risk | GO |
| Backend unit tests | `36 passed` (count increased vs older reports that said 30) | GO |
| API health + beta preflight | `curl /api/health`; `beta_preflight.py` all `[OK]` | GO |
| iOS simulator build | `xcodebuild` Debug iphonesimulator | GO |
| Android release pipeline | `clean assembleDebug assembleRelease bundleRelease lint` | GO |
| Device-token route auth | `Depends(get_current_user_id)` on `POST /device-token` (no admin token) | GO (code + smoke logs) |

## 3) What regressed (new failures)

| ID | Finding | Evidence | Status |
| --- | --- | --- | --- |
| R1 | Documentation drift: older audits cite `30 passed` | Current pytest `36 passed` | INTERNAL_FIXABLE (docs updated in this pass where cited) |
| R2 | None observed in executed gates | N/A | N/A |

## 4) Remaining blockers

| ID | Area | Change/Issue | Type | Priority | Evidence | Fix plan | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| B1 | Push live | FCM/APNs delivery to real devices | BLOCKED_EXTERNAL | P0_CRITICAL | Android: token path when local JSON exists; iOS needs Apple certs + device proof | Owner: Firebase + APNs per `docs/release/FIREBASE-APNS-FCM-SETUP.md` | OPEN |
| B2 | TestFlight / Play | Signed upload and store records | BLOCKED_EXTERNAL | P0_CRITICAL | Signing and console access | Owner checklists `IOS-TESTFLIGHT-RC-UPLOAD-STEPS.md`, `ANDROID-PLAY-INTERNAL-RC-UPLOAD-STEPS.md` | OPEN |
| B3 | Legal / store | Privacy URLs, labels, Data Safety | LEGAL_SIGNOFF_REQUIRED | P0_CRITICAL | Draft packets only | Legal review + ASC/Play forms | OPEN |
| B4 | Ops | Beta owner, on-call, WAF evidence | BLOCKED_EXTERNAL | P1_HIGH | `docs/ops/CLOSED-BETA-OPS-RUNBOOK.md` checkboxes open | Assign owners; attach evidence | OPEN |
| B5 | Android FCM token | Token fetch when `google-services.json` present | INTERNAL_FIXABLE | P1_HIGH | Conditional Gradle + `FcmFirebaseBootstrap` / `FcmTokenRefresher`; без JSON сборка без FCM | Live delivery still **BLOCKED_EXTERNAL** | PARTIAL → NEAR-GO code path |
| B6 | Real-device QA | Simulator/emulator-only evidence this run | NEEDS_MANUAL_QA | P1_HIGH | QA scripts under `docs/qa/` | Execute `HIAIR-RC1-REAL-DEVICE-QA-PACKET.md` | OPEN |

## 5) RC readiness impact

| Target | Closed Beta RC | Public launch |
| --- | --- | --- |
| Engineering gates (tests, smoke, preflight, mobile compile) | Unblocks **NEAR-GO** when evidence attached | Required not sufficient |
| Push E2E | **BLOCKED_EXTERNAL** until credentials + device | **NO-GO** without proof |
| Store upload | **BLOCKED_EXTERNAL** | **NO-GO** |
| Legal | Drafts → **LEGAL_SIGNOFF_REQUIRED** | **NO-GO** until signed |

**Verdict:** Closed Beta remains **NEAR-GO** at engineering layer; **not GO** for product launch until external + legal rows close.
