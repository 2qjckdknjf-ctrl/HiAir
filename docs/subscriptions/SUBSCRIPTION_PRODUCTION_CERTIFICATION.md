# Subscription Production Certification — 2026-07-10

**Commit under certification:** `5827bed` + follow-up fixes  
**Verdict:** **SUBSCRIPTION DEPLOYED — WAITING FOR TESTFLIGHT SANDBOX DEVICE**

---

## 1. Executive Summary

Privacy contract reconciled: **GDPR export/delete are auth-gated only, never Premium-gated** (prior sprint report matrix was documentation error). Production smoke confirms `/api/privacy/export` returns **401** without auth and **never 402**.

Backend deploy for `5827bed` **failed once** (Cloudflare Containers step, run `29072333018`). Production API still serves **2026-07-07** container image until redeploy succeeds. Deploy retry logic added to workflow; push triggers new attempt.

Mobile subscription client fixes (`5827bed`) are **not** in TestFlight build **65** — new build **14** (ASC number TBD) required.

**iOS sandbox E2E not executed** in this session (requires owner on physical iPhone + sandbox purchase).

---

## 2. Privacy Contract Result

| Endpoint | Free | Premium | Expected | Production (2026-07-10) |
|----------|------|---------|----------|-------------------------|
| `GET /api/privacy/export` (no auth) | 401 | 401 | 401 | **401** ✅ |
| `GET /api/privacy/export` (auth) | 200 or 404* | 200 | Never 402 | **404*** ✅ (no 402) |
| `POST /api/privacy/delete-account` (auth) | 200/404* | 200 | Never 402 | Not re-tested live |
| `GET /api/planner/daily` (free user) | 402 | 200 | 402 / 200 | **402** ✅ |
| `GET /api/subscriptions/me` (new user) | `is_premium=false` | — | false | **false** ✅ |

\*404 when Supabase user not yet provisioned in API DB (bridge/profile bootstrap); **not** a premium block.

**Code:** `backend/app/api/privacy.py` — no `require_premium` / `require_feature`.

**Regression tests:** `test_privacy_export_free_user_returns_200_not_402`, `post_deploy_api_smoke.py` 402 guard.

---

## 3. Deployed Version

| Item | Value |
|------|-------|
| Target commits | `5827bed` + certification + deploy recovery |
| **Root cause** | Expired/invalid **`CLOUDFLARE_API_TOKEN`** (GitHub production) |
| Failed step | `Deploy API to Cloudflare Containers` → `wrangler secret bulk` |
| CF API codes | `10000` Authentication error, `9109` Invalid access token |
| Failed runs | `29072333018`, `29072760859` |
| Last **success** | `28872808828` @ `ea66272` (2026-07-07) |
| Production `deploy_git_sha` | **absent** on `/api/health` (old image) |
| Owner runbook | `docs/_operator/cloudflare-deploy-token-runbook.md` |

---

## 4. Subscription Contract

| Feature | Free | Premium | Backend | iOS | Android |
|---------|------|---------|---------|-----|---------|
| Day planner | 402 | 200 | `planner.py` | `session.isPremium` + 402 | `state.isPremium` + 402 |
| Advanced insights | 402 | 200 | `insights.py` | 402 → paywall | 402 → paywall |
| Multiple profiles | 402 at limit | 200 | `profiles.py` | paywall | paywall |
| Custom alerts (PUT schedule) | 402 | 200 | `briefings.py` PUT | settings | settings |
| GDPR privacy export | 200/404* | 200 | **auth only** | no premium gate | no premium gate |
| Account delete | 200 | 200 | **auth only** | no premium gate | no premium gate |
| Wearable insights | flag off | future | `wearable_insights_enabled` | TBD | TBD |
| Premium exportable reports | flag off | future | `export_reports_enabled` | TBD | TBD |

---

## 5. TestFlight Build

| Item | Value |
|------|-------|
| Previous ASC build | **65** @ commit ~`9e82079` (no `5827bed` mobile fixes) |
| New `CURRENT_PROJECT_VERSION` | **14** (bumped in `project.yml`) |
| New archive | **UPLOADED** — ASC build **73** VALID (uploaded 2026-07-09) |
| CFBundleVersion | 14 (0.1.0) |
| Delivery UUID | `a7e38173-b060-4ca7-89cc-f596966b6c28` |
| Includes mobile fixes | `5827bed` entitlement sync |
| ASC IAP products | `com.hiair.premium.monthly` / `.yearly` — **READY_TO_SUBMIT**, prices+availability OK |

---

## 6. iOS Sandbox E2E

| Step | Result | Evidence |
|------|--------|----------|
| Fresh install TestFlight build 14+ | **NOT RUN** | — |
| Login → free entitlement | **NOT RUN** | prod smoke: `is_premium=false` |
| Planner blocked → paywall | **NOT RUN** | code path verified |
| Sandbox purchase | **NOT RUN** | owner + ASC sandbox tester |
| Backend verify → unlock | **NOT RUN** | — |
| Restart / re-login / restore | **NOT RUN** | — |

---

## 7. Restart / Re-login / Restore

| Scenario | Result |
|----------|--------|
| App restart keeps Premium | **NOT VERIFIED** |
| Re-login loads backend entitlement | **NOT VERIFIED** (code fix in `5827bed`) |
| Restore purchases | **NOT VERIFIED** |

---

## 8. Bugs Fixed (this certification)

| Fix | Area |
|-----|------|
| Privacy matrix doc corrected (export ≠ premium) | docs |
| Regression tests: privacy 200 not 402; planner 402 | backend tests |
| `subscription_production_smoke.py` | scripts |
| Cloudflare deploy 3× retry | CI workflow |
| iOS build 14 for subscription client fixes | `project.yml` |

---

## 9. Files Changed

- `backend/tests/test_subscriptions_entitlements.py`
- `docs/subscriptions/SUBSCRIPTION_PRODUCT_MODEL.md`
- `docs/subscriptions/SUBSCRIPTION_PRODUCTION_CERTIFICATION.md` (this file)
- `scripts/release/subscription_production_smoke.py`
- `.github/workflows/backend-deploy-production.yml`
- `mobile/ios/project.yml`

---

## 10. Android Status

**EXTERNALLY BLOCKED** — Play app `com.hiair` not created; code/tests ready; product IDs `hiair_premium_monthly` / `hiair_premium_yearly` aligned.

---

## 11. Remaining Blockers

1. **Rotate `CLOUDFLARE_API_TOKEN`** in GitHub production (see `docs/_operator/cloudflare-deploy-token-runbook.md`)
2. Re-run **Backend Deploy Production** workflow → confirm `deploy_git_sha` on `/api/health`
3. **Owner device** sandbox E2E (TestFlight ASC build **73** VALID)
4. **Play Console** app creation for Android E2E

---

## 12. Final Verdict

# BACKEND DEPLOY STILL BLOCKED

Rotate expired `CLOUDFLARE_API_TOKEN`, redeploy, verify `deploy_git_sha`, then proceed to iOS sandbox E2E on TestFlight build **73**.

---

## Owner: iOS Sandbox Runbook

1. Confirm workflow deploy **SUCCESS** after push
2. Install TestFlight ASC build **73** (CFBundleVersion 14)
3. Login with test account
4. Settings → confirm "Premium inactive"
5. Planner → Upgrade → paywall → products load
6. Purchase `com.hiair.premium.monthly` (sandbox tester)
7. Confirm planner unlocks without app restart
8. Kill app → reopen → still Premium
9. Logout → login → still Premium
10. Restore Purchases → still Premium
11. Settings → Privacy export → succeeds (no paywall)
