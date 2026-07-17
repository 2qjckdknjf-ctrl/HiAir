# HiAir Development Handoff for Next Agent

Date: 2026-07-17 (StoreKit products not loading)

## 0) Live status — StoreKit products / paywall (2026-07-17)

Branch `main` — product loading + paywall observation fix for TestFlight **build 81**.

- ❌ **Build 80 physical retest FAIL** — paywall opens; **no price**; Subscribe **non-responsive**; purchase sheet never opens; backend not reached
- 🔧 **Fix** — `SubscriptionService` via `EnvironmentObject`; service-owned product load; honest catalog states (loading/loaded/empty/failed); canonical `StoreProductIDs`; no dead subscribe buttons without Product
- ⏳ **Physical retest** — install build **81**; first checkpoint: prices + button + Apple sheet
- ✅ Production backend @ `07d5849` (unchanged for this defect)
- ❌ **Android Play E2E** — EXTERNALLY BLOCKED

**Verdict:** `CODE FIXED — WAITING FOR PHYSICAL PAYWALL RETEST` (after build 81 VALID)

### Owner device checklist (build 81)

1. Delete HiAir → install TestFlight **81**
2. Console: `subsystem:com.hiair.app category:subscription`
3. Planner → paywall → wait for loading → confirm `displayPrice` for monthly/yearly
4. One tap monthly → native Apple sheet must open (stop if not)
5. Only then complete purchase → entitlement → Planner unlock

See `docs/release/qa/REAL_DEVICE_QA_REPORT.md`.

## 0a) Prior — password loop (2026-07-15)

- Build 79: password loop FAIL
- Build 80: attempted sync/single-flight fix; products/paywall then failed

## 0b) Prior — subscription deploy (2026-07-14)

- ✅ Subscription backend on prod; smoke PASS
- TestFlight build 73 VALID but **obsolete** (no geo fix)

See `docs/subscriptions/SUBSCRIPTION_PRODUCTION_CERTIFICATION.md`.

## 0c) Prior — first-10-users track

Branch `release/mega-sprint-2-first-10-users` merged; live environmental backend deployed.

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
