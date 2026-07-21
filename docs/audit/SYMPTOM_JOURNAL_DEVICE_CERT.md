# Symptom Journal Device Certification

**Date:** 2026-07-21  
**Scope:** P0 taxonomy load recovery + journal readability redesign  
**iOS build target:** 93  

## Root cause (confirmed)

Production `GET /api/v1/health/symptoms/taxonomy` returned HTTP 200 with 79 symptoms, but the JSON used `severityNotice` while iOS `SymptomTaxonomyDTO` required non-optional `safetyNotice`. Decode failed → UI showed taxonomy load failure.

Android already accepted either key; iOS did not.

## Fixes shipped

1. Backend taxonomy payload includes both `safetyNotice` and `severityNotice`.
2. iOS decoder accepts either key (production-compatible without waiting for API deploy).
3. Catalog state machine: loading / loaded / failed / offline-cached.
4. Taxonomy cache + offline draft with client idempotency key.
5. UX: collapsible categories, search on labels, favorites/recents, entry sheet, history edit/delete.
6. Migration `020_symptom_client_request_id` on `hiair-prod`.
7. Android: collapsible categories, search without snake_case, cache fallback, `clientRequestId`.

## Honest status

Physical iPhone retest on build ≥93 is still required before claiming **SYMPTOM JOURNAL E2E VERIFIED**.

Until then: **CODE FIXED — WAITING FOR PHYSICAL RETEST**.
