# Real Device QA Report

## Physical Device Certification Sprint (2026-07-21)

### Executive status

**DEVICE CERTIFICATION IN PROGRESS**

Automated preflight, production deploy of product polish, physical install of build **92**, and TestFlight distribution are proven. Interactive HealthKit / StoreKit / geo / accessibility PASS on-device flows are **not** claimed — Maestro physical-device driver could not complete UI automation in this session (device flaky / team-id driver setup incomplete on Maestro 2.3.0 + Xcode 26.6).

Do not claim `READY FOR FIRST USERS` or `HEALTH INTELLIGENCE E2E VERIFIED` until the interactive matrix below is filled with PASS evidence.

---

## 1. Preflight (STAGE 1)

| Check | Result | Evidence |
|-------|--------|----------|
| Branch | PASS | `main` @ `fa0d91b` |
| Production health | PASS | `deploy_git_sha=fa0d91bcd294a779584daaf0ba6ed16751b6b065` |
| `/api/v1/health/summary` unauth | PASS | HTTP **401** (not 404) |
| `/api/v1/health/insights` unauth | PASS | HTTP **401** |
| Taxonomy unauth | PASS | HTTP **200** (public) |
| Migrations 018/019 on hiair-prod | PASS | Applied as `health_intelligence` + `symptom_logs_soft_delete_compat`; tables `wearable_metric_daily`, `wearable_sleep_summaries`, `wearable_sync_state`, `symptom_logs.deleted_at` present |
| Backend compileall + pytest | PASS | coverage ≥70% |
| iOS xcodegen/build/test | PASS | HiAirTests SUCCEEDED |
| Android assembleDebug/Release + lint + test | PASS | BUILD SUCCESSFUL |
| `hiair_final_gate.sh` | PASS | HiAir final gate: PASS |

---

## 2. Tested builds

| Platform | Build | Commit | Distribution |
|----------|-------|--------|--------------|
| iOS (device install) | **92** / 0.1.0 | `fa0d91b` | Direct install via `devicectl` (Apple Development) |
| iOS TestFlight | **92** | `fa0d91b` | ASC VALID; delivery `cbd0b02f-3f78-42e8-a939-945210419d8a`; groups «Первый»/«Первые» assigned; `IN_BETA_TESTING` |
| Android | assembleRelease local | `fa0d91b` | No physical Android attached (`adb devices` empty) |
| Backend prod | — | `fa0d91b` | Cloudflare Containers (auto after push) |

---

## 3. iOS Device E2E matrix

| Scenario | Result | Evidence |
|----------|--------|----------|
| Fresh install (devicectl uninstall+install) | **PASS** | App installed; CFBundleVersion **92** |
| Launch after unlock | **PASS** | `devicectl device process launch` succeeded once unlocked |
| Launch while locked | FAIL→blocked | FBSOpenApplicationError Locked (expected) |
| Auth | **NOT RUN** | Needs interactive / Maestro |
| Onboarding | **NOT RUN** | Needs interactive / Maestro |
| Location | **NOT RUN** | Needs interactive permission grant |
| Dashboard | **NOT RUN** | |
| HealthKit permissions | **NOT RUN** | |
| Real health records | **NOT RUN** | |
| Backend sync | **NOT RUN** | |
| Symptoms | **NOT RUN** | |
| Insights | **NOT RUN** | |
| StoreKit catalog | **NOT RUN** | Use TestFlight 92 + sandbox Apple ID |
| Purchase / Premium unlock | **NOT RUN** | |
| Restart / re-login / restore | **NOT RUN** | |
| Privacy | **NOT RUN** | |
| Offline | **NOT RUN** | |
| Accessibility | **NOT RUN** | |

### Automation blocker (not a product FAIL)

- Maestro 2.3.0 detected UDID `00008150-001E4C911100C01C` once, then required Apple Team ID / driver rebuild; subsequent runs reported device not connected.
- `--apple-team-id` may require Maestro ≥2.4; physical driver on Xcode 26.x has known packaging issues (`MaestroDriverLib`).
- No Android device connected → Android E2E **EXTERNALLY BLOCKED** for this session.

---

## 4. Operator next steps (human on iPhone)

Install **TestFlight build 92** (preferred for StoreKit) or continue on installed build 92.

1. Delete app → install TF 92 → confirm build 92 in Settings.
2. Onboarding → auth → Allow While Using App (location) → confirm Dashboard source live/cached (not 0,0).
3. Health: progressive tiers → confirm health grid rows appear (no zeros for missing) → sync.
4. Symptoms: taxonomy search + full context entry → red-flag notice.
5. Insights: today/trends; Premium locked card if free.
6. Paywall: real prices → sandbox purchase monthly → Planner 200 + Insights unlock.
7. Restart / logout+login / Restore / free account isolation.
8. Privacy export (free) / health delete / account delete confirm.
9. Offline + Dynamic Type XXL + VoiceOver + Dark/Light.

Never paste exact health values, coordinates, receipts, or Apple IDs into docs.

---

## 5. Historical notes (unchanged truth)

### Health Intelligence (2026-07-20)

Prior status before polish deploy: PRODUCTION DEPLOYED — WAITING FOR DEVICE HEALTH DATA (build 91). Superseded by this sprint for distribution, not for interactive E2E.

### StoreKit catalog (2026-07-18)

Build 81 physical paywall: **FAIL** (Request Canceled). Later code fixes shipped; **retest on TF 92 still required**.

---

Do not record Apple IDs, receipts, JWS, or exact coordinates.
