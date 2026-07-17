# Real Device QA Report

Status: **STOREKIT PRODUCTS NOT LOADING** (2026-07-17) — build 80 physical retest FAIL.

## Build 80 physical retest (2026-07-17)

| Item | Result | Notes |
|------|--------|-------|
| Physical iPhone session | **STARTED / FAIL** | TestFlight build 80 |
| Paywall opened | **PASS** | from Planner |
| Localized price | **MISSING** | showed pending / no StoreKit price |
| Subscribe button | **NON-RESPONSIVE** | disabled without Product |
| Native purchase sheet | **NOT OPENED** | |
| Backend verification | **NOT REACHED** | |
| Entitlement | **INACTIVE** | |
| Failure class | **PRODUCTS / PAYWALL STATE** | Case A pre-backend |

## Root cause (code, build 80)

1. `@ObservedObject private var subscriptionService = SubscriptionService.shared` — unreliable SwiftUI observation of singleton `@Published` updates.
2. Paywall rendered plan cards with `product == nil` → Subscribe `.disabled(true)` and placeholder price — looked “dead” without a clear empty-state CTA.
3. `.task`-scoped load could cancel before `Product.products` completed; load now owned by `SubscriptionService`.

## Fix build

| Item | Value |
|------|-------|
| Target build | **81** |
| Commit | pending upload |
| Changes | EnvironmentObject ownership; catalog states; service-owned load; canonical `StoreProductIDs` |

## Build 79 (prior)

Password authentication loop — fixed in 80; superseded by products/paywall FAIL on 80.

Do not record Apple IDs, receipts, JWS, or exact coordinates.
