# Real Device QA Report

Status: **STOREKIT CATALOG FAIL — Request Canceled** (2026-07-18) — build 81 physical paywall retest FAIL.

## Build 81 physical paywall retest (2026-07-18)

| Item | Result | Notes |
|------|--------|-------|
| Physical iPhone session | **FAIL** | TestFlight build 81 |
| Paywall opened | **PASS** | |
| UI message | **FAIL** | «Планы недоступны…» + **Request Canceled** |
| Localized price | **MISSING** | |
| Subscribe button | **UNAVAILABLE** | |
| Native purchase sheet | **NOT OPENED** | |
| Backend verify | **NOT REACHED** | |
| Entitlement | **INACTIVE** | |

Previous status “waiting for physical paywall retest” is obsolete — retest ran and **FAILED**.

## Confirmed diagnostics

| Item | Result |
|------|--------|
| ASC products | READY_TO_SUBMIT, prices=175, availability=175 territories |
| Product IDs | match canonical `com.hiair.premium.monthly` / `.yearly` |
| Device error | StoreKit / network **Request Canceled** (NSURLErrorCancelled class) |
| Root cause (code) | Product.products fetch cancellable under MainActor/UI lifecycle; raw cancel surfaced to UI |
| Agreements | **Owner must confirm** Paid Apps Active (ASC login required; API `/v1/agreements` unavailable) |

## Fix build

| Item | Value |
|------|-------|
| Target | **82** |
| Commit | `dc26890` |
| ASC | **VALID** |
| Delivery UUID | `ce491fb6-8af8-464a-9f23-01da982e79c2` |
| Changes | `Task.detached` StoreKit fetch; cancel retry; friendly error copy; scheme StoreKit config removed from Run |

Do not record Apple IDs, receipts, JWS, or exact coordinates.
