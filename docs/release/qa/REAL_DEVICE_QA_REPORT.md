# Real Device QA Report

## Physical Device Certification Sprint (2026-07-21, session refresh)

### Executive status

**DEVICE CERTIFICATION IN PROGRESS**

Automated preflight is green again (including final gate after arm64 JDK fix). Physical iPhone 17 Pro is paired; HiAir **build 92** was reinstalled via signed `devicectl` install and launched. Interactive HealthKit / StoreKit / geo / accessibility / Premium purchase flows are **still NOT RUN** — Maestro 2.7.0 cannot attach to this device over CoreDevice local-network pairing (`Device … was requested, but it is not connected`), and no USB/idb UI driver is available in this environment.

Do **not** claim `READY FOR FIRST USERS` or `HEALTH INTELLIGENCE E2E VERIFIED` until the interactive matrix below has PASS evidence from a human (or USB-attached Maestro/XCUITest).

---

## 1. Preflight (STAGE 1) — re-verified 2026-07-21 ~15:55 CEST

| Check | Result | Evidence |
|-------|--------|----------|
| Branch | PASS | `main` @ `106f30e` (docs) / product polish `fa0d91b` |
| Working tree (product) | PASS | No uncommitted iOS/Android product diffs vs origin/main; only ops docs / `.tools` noise |
| Production health | PASS | `deploy_git_sha=fa0d91bcd294a779584daaf0ba6ed16751b6b065` |
| `/api/v1/health/summary` unauth | PASS | HTTP **401** (not 404) |
| `/api/v1/health/insights` unauth | PASS | HTTP **401** |
| Taxonomy unauth | PASS | HTTP **200** |
| Migrations health + soft-delete on hiair-prod | PASS | `health_intelligence`, `symptom_logs_soft_delete_compat`; tables/columns present |
| Backend compileall + pytest | PASS | coverage ≥70% |
| iOS xcodegen/device build + HiAirTests | PASS | device Debug signed build SUCCEEDED; HiAirTests SUCCEEDED |
| Android assembleDebug/Release + lint + test | PASS | BUILD SUCCESSFUL (JAVA_HOME=JBR 17 arm64) |
| `hiair_final_gate.sh` | PASS | After fix: prefer `/usr/libexec/java_home -v 17` under `bash -lc` (avoids x86 Homebrew java) |

---

## 2. Tested builds

| Platform | Build | Commit | Distribution |
|----------|-------|--------|--------------|
| iOS (device install) | **92** / 0.1.0 | `fa0d91b` product + current tree | Signed Apple Development via `devicectl` (fresh uninstall → reinstall 2026-07-21) |
| iOS TestFlight | **92** | `fa0d91b` | ASC **VALID**, not expired; id `cbd0b02f-3f78-42e8-a939-945210419d8a` |
| Android | assembleRelease local | `fa0d91b` | No physical Android (`adb` unavailable) |
| Backend prod | — | `fa0d91b` | Cloudflare Containers |

---

## 3. iOS Device E2E matrix

| Scenario | Result | Evidence |
|----------|--------|----------|
| Fresh install (uninstall + signed install) | **PASS** | `devicectl uninstall` → signed Debug-iphoneos install → CFBundleVersion **92** |
| Launch after unlock | **PASS** | `devicectl device process launch` → process running |
| Maestro UI automation | **BLOCKED (tooling)** | Maestro 2.7: UDID requested but “not connected” (localNetwork CoreDevice; USB not visible to Maestro) |
| Auth | **NOT RUN** | Needs interactive / USB Maestro |
| Onboarding | **NOT RUN** | |
| Location | **NOT RUN** | |
| Dashboard | **NOT RUN** | |
| HealthKit permissions | **NOT RUN** | |
| Real health records | **NOT RUN** | |
| Backend sync | **NOT RUN** | |
| Symptoms | **NOT RUN** | |
| Insights | **NOT RUN** | |
| StoreKit catalog | **NOT RUN** | Use **TestFlight 92** + sandbox Apple ID (dev install StoreKit may differ) |
| Purchase / Premium unlock | **NOT RUN** | |
| Restart / re-login / restore | **NOT RUN** | |
| Privacy | **NOT RUN** | |
| Offline | **NOT RUN** | |
| Accessibility | **NOT RUN** | |

### Automation blocker (not a product FAIL)

- Device transport: `localNetwork` CoreDevice tunnel works for install/launch; Maestro physical driver does not enumerate the UDID.
- USB cable not presenting as Maestro/libimobiledevice connection in this session.
- No Android USB device → Android E2E **EXTERNALLY BLOCKED**.

---

## 4. Operator next steps (human on iPhone)

Prefer **TestFlight build 92** for StoreKit sandbox (dev-signed install is OK for Health/geo/symptoms only).

1. Delete app → install TF 92 → confirm build 92 in Settings → About.
2. Onboarding → auth → Allow While Using App → Dashboard source live/cached (not 0,0).
3. Health tiers → health grid rows (missing ≠ zero) → sync.
4. Symptoms: taxonomy + full context + red-flag notice (wellness only).
5. Insights today/trends; Premium locked card if free.
6. Paywall: real prices → sandbox monthly → Planner 200 + Insights unlock.
7. Restart / logout+login / Restore / free-account isolation.
8. Privacy export (free) / health delete / account delete confirm.
9. Offline + Dynamic Type XXL + VoiceOver + Dark/Light.

Never paste exact health values, coordinates, receipts, or Apple IDs into docs.

---

## 5. Bugs found this session

| Bug | Severity | Fix |
|-----|----------|-----|
| `hiair_final_gate.sh` Android step failed under `bash -lc` due to x86_64 Homebrew `/usr/local/bin/java` (“Bad CPU type”) | P0 preflight | Gate now resolves arm64 JDK via `java_home -v 17` / JBR and exports `JAVA_HOME` for gradle |
| Unsigned DerivedData app reinstall attempt after uninstall | operator error | Rebuilt with Automatic signing + Team `43A4KW5BKB`; reinstalled successfully |

---

## 6. Historical notes

### Health Intelligence (2026-07-20)

PRODUCTION LIVE; device HealthKit E2E still waiting for interactive PASS.

### StoreKit (2026-07-18 → 92)

Build 81 paywall FAIL (Request Canceled). Code fixes shipped; **retest on TF 92 still required**.

---

Do not record Apple IDs, receipts, JWS, or exact coordinates.
