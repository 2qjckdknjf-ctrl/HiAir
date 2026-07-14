# Real Device QA Report

Status: **STOREKIT PURCHASE FLOW FAILED** (2026-07-15) — physical iPhone session started; password authentication loop on build 79.

## StoreKit purchase failure (2026-07-15)

| Item | Result | Notes |
|------|--------|-------|
| Physical iPhone session | **STARTED** | TestFlight build 79 |
| StoreKit purchase | **FAIL** | Apple ID password sheet loops; purchase never completes |
| Premium entitlement | **NOT ACTIVE** | backend not reached (pre-backend failure class) |
| Planner unlock | **FAIL** | paywall remains |
| Root cause (suspected) | **CODE** | concurrent `AppStore.sync()` during paywall load + purchase; fix in progress |
| Fix build | **PENDING** | build 80 with single-flight guard + no sync on product load |

## Geolocation device (build 79)

| Scenario | Result | Notes |
|----------|--------|-------|
| Physical session started | **YES** | same device session as subscription test |
| StoreKit purchase | **FAIL** | blocks full geo+subscription integration proof |

## Subscription device scenarios

| Scenario | Result | Notes |
|----------|--------|-------|
| Products load (assumed) | **LIKELY PASS** | paywall opened; purchase sheet appeared |
| Sandbox purchase | **FAIL** | password loop |
| Backend verify | **NOT REACHED** | no entitlement activation |
| Planner unlock | **FAIL** | |
| Restart / re-login / restore | **NOT RUN** | blocked on purchase |

## Engineering status

| Item | Result |
|------|--------|
| Production @ `07d5849` | PASS |
| TestFlight build 79 | VALID (obsolete after fix) |
| Automated tests | PASS (pre-fix) |
| ASC IAP products | READY_TO_SUBMIT |

Do not record exact coordinates, Apple IDs, receipts, or tokens in this document.
