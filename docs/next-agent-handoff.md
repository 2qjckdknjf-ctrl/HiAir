# HiAir Development Handoff for Next Agent

Date: 2026-07-19 (Health Intelligence certification in progress)

## 0) Health Intelligence release certification (2026-07-19)

- Branch: `feat/health-intelligence-expansion` (base `0409b24` + review tails)
- Migration `018` / `health_intelligence`: **already on hiair-prod** (do not re-apply blindly)
- Local gates: backend suite + `hiair_final_gate.sh` **PASS**
- **Not done yet:** merge → Backend Deploy Production → smoke `/api/v1/health/*` → TestFlight build **>84** → physical HealthKit + Health Connect E2E
- Honest status until device evidence: never claim `HEALTH INTELLIGENCE E2E VERIFIED`
- Docs: `docs/health/HEALTH_INTELLIGENCE_RELEASE_STATUS.md`, `docs/health/API_CONTRACT.md`

## 0a) Live status — StoreKit catalog Request Canceled (2026-07-18)

- ❌ **Build 81 physical FAIL** — paywall shows unavailable + **Request Canceled**; no prices; no Apple sheet; backend not reached
- ✅ ASC products READY_TO_SUBMIT (prices + 175 territories) via API
- 🔧 **Build 82** — detached StoreKit product fetch; cancel retry; honest error copy
- ⏳ Owner: confirm **Paid Apps Agreement / Tax / Banking Active**; retest build 82 catalog first
- ❌ Android Play E2E — EXTERNALLY BLOCKED

**Verdict after upload:** `CODE FIXED — WAITING FOR PHYSICAL PAYWALL RETEST` unless catalog still empty → then Agreements/ASC blocker.

### Owner build 82 checklist

1. Delete HiAir → install TestFlight **82**
2. Console: `subsystem:com.hiair.app category:subscription` — look for `returned_product_count`, `products_load_failed`
3. Paywall → prices visible → one tap monthly → Apple sheet
4. If still empty/canceled: App Store Connect → Business → Agreements → Paid Apps **Active**

See `docs/release/qa/REAL_DEVICE_QA_REPORT.md`.

## 0a) Prior — products not loading (build 80)

EnvironmentObject + catalog states; still failed on 81 with Request Canceled.

## 0b) Prior — password loop (build 79)

Fixed in 80 (removed AppStore.sync from product load).

## 0c) Prior — subscription deploy / first-10-users

Production backend @ `07d5849`; geo engineering closed.

---

## Quick commands

```bash
curl -sS https://api.hiair.io/api/health
.tools/py/python/bin/python3.12 scripts/release/subscription_production_smoke.py
bash scripts/release/hiair_final_gate.sh
cd mobile/ios && bash scripts/archive_and_upload_testflight.sh
cd mobile/ios && bash scripts/upload_ipa_testflight_api.sh
```

## Docs

- Geolocation: `docs/feat-geolocation-flow.md`
- Subscriptions: `docs/subscriptions/SUBSCRIPTION_PRODUCTION_CERTIFICATION.md`
- Device QA: `docs/release/qa/REAL_DEVICE_QA_REPORT.md`
