# Real Device QA Report

## P0 Runtime UX Recovery (2026-07-25)

**CODE FIXED — WAITING FOR PHYSICAL RETEST**

PR #34 merged to `main` @ `cda6722`. TestFlight **build 127** is **VALID**, assigned to «Первый», `IN_BETA_TESTING`.

Do **not** mark City / Health / Premium / revoke-safety as device PASS until the physical iPhone matrix below is measured on **TF 127**.

Evidence index: `docs/audit/P0_RUNTIME_UX_RECOVERY.md`

### Physical matrix (TF 127) — NOT RUN

| Flow | Target | Result |
|------|--------|--------|
| Cached same-account city | immediate | **NOT RUN** |
| New locality | <3 s | **NOT RUN** |
| Health permission UI exit | immediate | **NOT RUN** |
| Health background sync | non-blocking | **NOT RUN** |
| Premium Activating | immediate | **NOT RUN** |
| Premium server confirm | <2 s | **NOT RUN** |
| Revoke during sync | no upload | **NOT RUN** |
| Account isolation | no leakage | **NOT RUN** |

---

## P0 Device Recovery (2026-07-23)

**CODE FIXED — WAITING FOR PHYSICAL RETEST**

Fixes are on branch `fix/p0-device-recovery` (startup / geo / HealthKit / StoreKit). Do **not** mark Startup, Location, HealthKit, or Premium as device PASS until a TestFlight build **>109** completes the Phase 18 matrix on a physical iPhone.

Evidence index: `docs/audit/P0_DEVICE_RECOVERY_FINAL_REPORT.md`

---

## Stage 0 update (2026-07-23)

Production API is now on `0243952` (matches `main`). Latest TestFlight is build **109** (`VALID`, `READY_FOR_BETA_TESTING`). Synthetic Health / AI / Premium API smokes PASS. Interactive HealthKit / Health Connect / StoreKit / geo matrices remain **NOT RUN** on a physical device — see `docs/audit/STAGE0_FINAL_CERTIFICATION.md`.

Do **not** claim `HEALTH INTELLIGENCE E2E VERIFIED` without real wearable records on device.

## Health Intelligence release certification (2026-07-21)

### Executive status

**PRODUCTION DEPLOYED — WAITING FOR DEVICE HEALTH DATA**

*(Historical snapshot below; superseded for SHA/TF by Stage 0 update above.)*

Production API was on `28696b0` with synthetic Health Intelligence smoke PASS. TestFlight **build 103** was VALID and assigned to «Первый». Interactive HealthKit / Health Connect / StoreKit / geo matrices are **still NOT RUN** on a physical device in this session.

---

## 1. Preflight / production (re-verified)

| Check | Result | Evidence |
|-------|--------|----------|
| Branch | PASS | `main` @ `28696b0` |
| Production health | PASS | `deploy_git_sha=28696b020aa1a0e7c895e2e17a0b95431dac1690` |
| Deploy workflow | PASS | https://github.com/2qjckdknjf-ctrl/HiAir/actions/runs/29847279318 |
| Health unauth | PASS | summary/availability/sync/data **401** |
| Synthetic auth smoke | PASS | `scripts/release/health_intelligence_production_smoke.py` |
| Live AI | PASS | `/api/air/current-risk` `explanationSource=llm` |
| Backend pytest | PASS | coverage ≥70% |
| iOS Release sim build | PASS | build 103 tree |
| Android signed release | PASS | APK Signature Scheme v2; API `https://api.hiair.io` |

---

## 2. Tested builds

| Platform | Build | Commit | Distribution |
|----------|-------|--------|--------------|
| iOS TestFlight | **103** | post-merge Health Intel + fixes | ASC **VALID** `dce5426e-14b0-4fb1-bbf4-0c04648afaa2`; group «Первый»; `IN_BETA_TESTING` |
| Android | signed `app-release.apk` | `28696b0` tree | Local artifact; no Play upload; no physical device |
| Backend prod | — | `28696b0` | Cloudflare Containers |

---

## 3. iOS Device Health E2E matrix (TF 103)

| Scenario | Result | Evidence |
|----------|--------|----------|
| Fresh install TF 103 | **NOT RUN** | |
| Login | **NOT RUN** | |
| Health settings / tiers 1–3 | **NOT RUN** | |
| Real HealthKit records read | **NOT RUN** | |
| Backend sync | **NOT RUN** | |
| Dashboard health grid | **NOT RUN** | |
| Insights 7 / 30 | **NOT RUN** | |
| Personal load | **NOT RUN** | |
| Live AI with health context | **NOT RUN** | |
| Partial permissions / no-record | **NOT RUN** | |
| Restart persistence | **NOT RUN** | |
| Revoke + delete | **NOT RUN** | |
| Privacy export | **NOT RUN** | |
| StoreKit sandbox purchase | **NOT RUN** | |
| Geo / symptoms regression | **NOT RUN** | |

### Automation blocker (not a product FAIL)

- Maestro 2.7 over CoreDevice localNetwork still cannot attach; USB preferred.
- No Android USB device → HC E2E **EXTERNALLY BLOCKED** until device available.

---

## 4. Android Health Connect matrix

| Scenario | Result |
|----------|--------|
| HC availability | **NOT RUN** |
| Permissions + real records | **NOT RUN** |
| Temperature / OEM unsupported honesty | **NOT RUN** |
| Sync / Dashboard / Insights 7/30 | **NOT RUN** |
| Revoke / delete | **NOT RUN** |
| Play Billing | **EXTERNALLY BLOCKED** |

---

## 5. Operator next steps (human)

Prefer **TestFlight build 103** against production.

1. Delete app → install TF 103 → confirm build 103.
2. Auth → Health tiers 1–3 → real records → sync (no mock).
3. Dashboard grid + Insights 7/30 + personal load.
4. Premium path for advanced insights if testing AI health_context.
5. Revoke / delete / privacy export (free).
6. Cross-check subscription, geo, symptoms still work.
7. Android: install signed release APK → Health Connect matrix.

Never paste exact health values, coordinates, receipts, or Apple IDs into docs.
