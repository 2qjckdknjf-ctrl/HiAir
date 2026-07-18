# Subscription Production Certification — 2026-07-18

**Verdict:** **STOREKIT CATALOG STILL EMPTY ON DEVICE (build 81) — FIX BUILD 82**

---

## Physical failure (build 81)

| Item | Result |
|------|--------|
| Prices | missing |
| Subscribe | unavailable |
| Apple sheet | not opened |
| Backend | not reached |
| UI error | **Request Canceled** |

Retest is complete and **FAIL** — not “waiting for retest”.

---

## ASC product audit (API)

| Product | Type | Status | Price | Availability | Metadata |
|---------|------|--------|-------|--------------|----------|
| monthly | Auto-Renewable | READY_TO_SUBMIT | 175 territories | 175 territories | locs en-US+ru, screenshot COMPLETE |
| yearly | Auto-Renewable | READY_TO_SUBMIT | 175 territories | 175 territories | locs en-US+ru, screenshot COMPLETE |

Bundle: `com.hiair.app` / ASC app `6773610034` / group **HiAir Premium**.

## Business status

| Item | Status |
|------|--------|
| Paid Apps Agreement | **UNKNOWN — owner login required** at App Store Connect → Business → Agreements |
| Tax | Owner confirm Complete/Active |
| Banking | Owner confirm Active |
| Contact info | Owner confirm Complete |

API key cannot read `/v1/agreements` (404/not exposed).

---

## Code fix (build 82)

1. Fetch `Product.products` via `Task.detached` so SwiftUI ProgressView swap cannot cancel StoreKit.
2. Treat Request Canceled / NSURLErrorCancelled as retryable (max 2 attempts).
3. Never show raw “Request Canceled” as primary copy.
4. Neutral empty/fail copy (no false “linked to TestFlight build” claim).
5. Remove `.storekit` from shared Run scheme (Archive already clean).

Backend unchanged for this defect.
