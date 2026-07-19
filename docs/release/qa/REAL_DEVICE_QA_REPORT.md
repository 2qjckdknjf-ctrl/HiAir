# Real Device QA Report

## Health Intelligence (2026-07-19)

Status: **RELEASE BLOCKED** — merged `4cac2c36`; production deploy blocked by invalid Cloudflare token; physical HealthKit / Health Connect reads pending.

| Item | Result | Notes |
|------|--------|-------|
| Migration 018/019 (hiair-prod) | PASS | 018 once; 019 idempotent compat |
| Local/CI final gates | PASS | including PR #29 CI |
| Production `/api/v1/health/*` | FAIL | 404; API still `07d5849` |
| Physical iPhone HealthKit read | NOT RUN | Required for E2E |
| Physical Android Health Connect read | NOT RUN | Required for E2E |
| Symptom + insight on device | NOT RUN | No exact values logged |

Do not claim `HEALTH INTELLIGENCE E2E VERIFIED` without real-device evidence.

---

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
