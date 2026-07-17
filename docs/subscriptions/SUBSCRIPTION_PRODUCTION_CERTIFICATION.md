# Subscription Production Certification — 2026-07-17

**Production SHA:** `07d584959db412553f70800c4a49ae109021eb25` (backend unchanged for this defect)  
**Verdict:** **STOREKIT PRODUCTS NOT LOADING ON BUILD 80 — FIX BUILD 81**

---

## Physical retest evidence (build 80)

| Check | Result |
|-------|--------|
| Paywall opened | PASS |
| Products / price displayed | **FAIL** |
| Subscribe button | **NON-RESPONSIVE** |
| Native purchase sheet | **NOT OPENED** |
| Backend `/ios/verify` | **NOT REACHED** |
| Entitlement active | **NO** |
| Planner unlock | **NO** |

Previous status “waiting for physical retest” is obsolete — retest ran and **FAILED**.

---

## ASC products (API audit 2026-07-17)

| Product | State | Prices | Availability | Localizations |
|---------|-------|--------|--------------|---------------|
| `com.hiair.premium.monthly` | READY_TO_SUBMIT | 175 | yes | 2 |
| `com.hiair.premium.yearly` | READY_TO_SUBMIT | 175 | yes | 2 |

Note: build **79** previously opened the Apple purchase sheet (password loop), so ASC catalog can return products. Build **80** failure aligns with client observation/UX regression, not a sudden product-ID mismatch.

## Agreements

ASC Management API `/v1/agreements` not available with current key. Owner must confirm in App Store Connect → Business → Agreements / Tax / Banking that **Paid Apps Agreement** is Active. If inactive, StoreKit may return empty catalogs.

---

## Honest status ladder

Still **ARCHITECTURE READY** — not STORE SANDBOX READY until build 81+ shows prices, opens purchase sheet, verifies entitlement, unlocks Planner.
