# Subscription Production Certification — 2026-07-15

**Production SHA:** `07d584959db412553f70800c4a49ae109021eb25`  
**Verdict:** **STOREKIT PURCHASE FLOW FAILED ON PHYSICAL IPHONE — FIX IN PROGRESS**

---

## Physical device evidence (2026-07-15)

| Event | Result |
|-------|--------|
| Physical iPhone session | **STARTED** |
| TestFlight build 79 | Installed |
| Paywall → monthly purchase | Password sheet loops |
| StoreKit terminal success | **NOT OBSERVED** |
| Backend `/api/subscriptions/ios/verify` | **NOT REACHED** |
| `is_premium=true` | **NO** |
| Planner unlock | **NO** |

**Failure class:** Case A — pre-backend (StoreKit / concurrent auth prompts).

**Suspected root cause:** `AppStore.sync()` called up to 3× on paywall open (`loadProducts`) overlapping `product.purchase()` authentication.

**Fix:** build 80 — remove sync from product load; single-flight purchase guard; restore existing entitlements before repurchase; structured diagnostics.

---

## Backend contract (unchanged, verified in automation)

| Endpoint | Free | Premium |
|----------|------|---------|
| `GET /api/privacy/export` | never 402 | never 402 |
| `GET /api/planner/daily` | 402 | 200 |
| `POST /api/subscriptions/ios/verify` | — | grants entitlement |

---

## ASC IAP

| Product | ASC state |
|---------|-----------|
| `com.hiair.premium.monthly` | READY_TO_SUBMIT, prices + availability |
| `com.hiair.premium.yearly` | READY_TO_SUBMIT, prices + availability |

---

## Honest status ladder

**ARCHITECTURE READY** — not **STORE SANDBOX READY** until physical retest passes on fix build.
