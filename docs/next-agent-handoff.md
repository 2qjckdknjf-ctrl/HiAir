# HiAir Development Handoff for Next Agent

Date: 2026-07-14 (FINAL P0 device certification)

## 0) Live status — StoreKit password loop recovery (2026-07-15)

Branch `main` — fix in progress for StoreKit purchase authentication loop.

- ✅ **Physical iPhone session STARTED** — TestFlight build 79
- ❌ **StoreKit purchase FAIL** — Apple ID password sheet loops; entitlement never activates
- 🔧 **Fix** — remove `AppStore.sync()` from product load; single-flight purchase guard; build **80** upload pending
- ⏳ **Physical retest** — owner one controlled purchase on build 80 after VALID
- ✅ Production backend @ `07d5849`; geo engineering closed
- ❌ **Android Play E2E** — EXTERNALLY BLOCKED

**Verdict:** `STOREKIT CODE FIXED — WAITING FOR PHYSICAL RETEST` (after build 80 upload)

### Owner device checklist (build 79)

1. Delete old HiAir → install TestFlight **79**
2. Login → onboarding → Allow location → verify dashboard live for actual area (city-level only in notes)
3. Planner paywall (402) before purchase
4. Sandbox monthly purchase → wait for backend `is_premium=true` → Planner opens
5. Kill app → Premium persists
6. Logout → login same account → Premium restored
7. Logout → different free account → no Premium leak
8. Restore Purchases on purchased Apple ID

See `docs/release/qa/REAL_DEVICE_QA_REPORT.md`.

## 0a) Prior — subscription deploy (2026-07-14)

- ✅ Subscription backend on prod; smoke PASS
- TestFlight build 73 VALID but **obsolete** (no geo fix)

See `docs/subscriptions/SUBSCRIPTION_PRODUCTION_CERTIFICATION.md`.

## 0b) Prior — first-10-users track

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
