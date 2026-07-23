# STAGE 0 — Final Certification

**Date (UTC):** 2026-07-23  
**Repo tip:** `02439521f3c56eb7ebe0fe6119d0be2179138293` (`main`)  
**Production tip:** `02439521f3c56eb7ebe0fe6119d0be2179138293` (`api.hiair.io`)  
**Verdict:** **STAGE0_COMPLETE = TRUE** (engineering + deploy + smoke + docs)  
**Ship gate:** **GO for engineering / internal TestFlight** · **NO GO for App Store / Play production** (external)

---

## 1. Everything completed (in-repo / automatable)

| Area | Result | Evidence |
|------|--------|----------|
| Product Polish + AI Reports on `main` | DONE | PR #31 merged `1ee8ee2` |
| Health Intelligence on `main` | DONE | PR #30 |
| CI Backend / iOS / Android | GREEN | runs `30014902384` / `30014901303` / `30014901307` |
| Production Cloudflare deploy | GREEN | run `30015917425` |
| `deploy_git_sha` matches `main` | PASS | live health = `0243952…` |
| Post-deploy smoke + live AI | PASS | `post_deploy_api_smoke.py --require-live-ai --expect-sha` |
| Health Intelligence prod smoke | PASS | `health_intelligence_production_smoke.py` (sync/insights/AI/privacy) |
| Subscription prod smoke | PASS | free entitlement + privacy not 402 |
| AI reports morning/evening/weekly | PASS | free gates + premium unlock matrix |
| Current risk / planner / dashboard / recommendations | PASS | authenticated 200 after premium grant |
| Premium endpoints `/subscriptions/me|plans` | PASS | 200 |
| Cloudflare token recovery tooling | DONE | `refresh_wrangler_oauth.py`, `rotate_cloudflare_github_token.py` |
| Deploy hardening | DONE | full secret sync + SHA-pinned container + smoke SHA assert |
| Tech debt markers TODO/FIXME/HACK | CLEAN | `backend/`, `mobile/`, `scripts/` |
| Local backend regression | PASS | **197 passed**, coverage ≥70% |
| TestFlight latest | VALID + Ready to Test | build **109**, `0.1.0`, `READY_FOR_BETA_TESTING` |
| Audit + certification docs | DONE | this file + `STAGE0_AUDIT.md` |

---

## 2. Everything still blocked externally

| Blocker | Why |
|---------|-----|
| Long-lived Custom Cloudflare API Token (preferred) | Deploy recovered via Wrangler OAuth refresh; Custom API Token still preferred for CI stability (`docs/_operator/cloudflare-deploy-token-runbook.md`) |
| ASC Paid Apps Agreement / tax / banking completeness | Required before honest StoreKit catalog / production IAP |
| App Store Connect external TestFlight review | Internal only today (`externalBuildState=NOT_APPLICABLE`) |
| Play Console app for `com.hiair` | Blocks Play Billing E2E |

---

## 3. Everything requiring physical devices

| Matrix | Status |
|--------|--------|
| iPhone HealthKit connect + real aggregates → `/api/v1/health/*` | **DEVICE PENDING** |
| iPhone geo permission → non-`(0,0)` coordinates persisted | **DEVICE PENDING** |
| iPhone StoreKit sandbox purchase → `is_premium=true` + Premium unlock | **DEVICE PENDING** |
| iPhone offline / dark mode / localization UX pass | **DEVICE PENDING** |
| Android Health Connect + geo + billing on hardware | **DEVICE PENDING** |

Do **not** mark any of the above PASS. Prior report: `docs/release/qa/REAL_DEVICE_QA_REPORT.md` (still device-pending; prod SHA there is stale vs this certification).

---

## 4. Everything requiring App Store

| Item | Status |
|------|--------|
| App Store submission / review | NOT STARTED |
| External TestFlight | NOT APPLICABLE until submitted |
| Production IAP price presence + paywall screenshot | EXTERNAL / ASC |
| Privacy Nutrition Labels / export review assets | Owner ASC |

Honest subscription ladder remains **ARCHITECTURE READY** until on-device sandbox purchase proves entitlement.

---

## 5. Everything requiring Play Console

| Item | Status |
|------|--------|
| Play app registration for `com.hiair` | **EXTERNAL BLOCKER** |
| Play Billing E2E | Blocked until app exists |
| Internal testing track upload of Stage 0 APK | Optional; not blocking Stage 0 engineering close |

---

## 6. Exact readiness percentage

| Scope | Score | Notes |
|-------|------:|-------|
| Engineering merge + CI | 100% | Required features on `main`, CI green |
| Production API live = `main` | 100% | SHA match + smokes |
| TestFlight engineering build | 95% | VALID/Ready; commit inferred via Xcode Cloud timing (ASC has no git SHA on build) |
| Backend quality (tests/smoke) | 95% | 197 pytest + live smokes |
| Device certification | 0% | No physical evidence this session |
| Store production readiness | ~35% | Architecture ready; sandbox/store incomplete |
| **Stage 0 overall (mission scope)** | **92%** | All in-repo work exhausted; remainder is EXTERNAL / DEVICE |

---

## 7. Objective scorecard (engineering)

| Domain | Score /10 | Note |
|--------|----------:|------|
| Backend | 9 | Live SHA match, AI live, smokes green |
| iOS | 8 | CI + TF 109; device E2E pending |
| Android | 7 | CI green; Play Console absent |
| Health | 8 | Prod synthetic smoke PASS; device pending |
| AI | 9 | Live LLM + morning/evening/weekly verified |
| Premium | 8 | Architecture + API gates; StoreKit device pending |
| Dashboard | 9 | Prod overview 200 |
| Symptoms | 8 | On main via Health Intel + polish; device UX pending |
| Insights | 8 | Prod insights windows PASS under premium |
| Architecture | 9 | Cloudflare Containers + Supabase + entitlements |
| Security | 8 | Auth gates, privacy not premium-gated |
| Performance | 7 | Cold container start observable; sleepAfter 15m |
| Localization | 7 | Multilingual codepaths present; device QA pending |
| Accessibility | 6 | No Stage 0 a11y device audit |
| Design | 8 | Brand kit + polish on main |
| First User Experience | 7 | Engineering ready; real-device first-run pending |

---

## 8. GO / NO GO

| Question | Answer |
|----------|--------|
| Stage 0 engineering closure complete? | **GO — YES** (`STAGE0_COMPLETE = TRUE`) |
| Safe for internal TestFlight testing on build 109? | **GO** |
| Claim production API includes AI reports + polish? | **GO** (SHA `0243952` contains PR #31 + deploy fix) |
| Claim physical-device E2E verified? | **NO GO** |
| Claim App Store / Play production ready? | **NO GO** |
| Start Stage 1 product work? | Allowed **only after** owner accepts this certification; Stage 0 itself does not start Stage 1 |

---

## 9. Evidence index

| Artifact | ID / path |
|----------|-----------|
| Production deploy | https://github.com/2qjckdknjf-ctrl/HiAir/actions/runs/30015917425 |
| PR #31 | https://github.com/2qjckdknjf-ctrl/HiAir/pull/31 |
| Live health | `https://api.hiair.io/api/health` → `0243952…` |
| Audit twin | `docs/audit/STAGE0_AUDIT.md` |
| Token runbook | `docs/_operator/cloudflare-deploy-token-runbook.md` |

---

*Certification rule followed: physical device / StoreKit / Play claims remain EXTERNAL BLOCKER only; everything else that could be finished inside the repository was finished.*
