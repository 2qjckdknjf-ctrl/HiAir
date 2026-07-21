# Symptom Journal Device Certification

**Date:** 2026-07-21  
**Scope:** P0 taxonomy load recovery + journal readability redesign  
**iOS TestFlight build:** 95 — **VALID** (`b5339c77-77e8-499b-859d-d7aa34672ce7`), assigned to internal group «Первый»  
**Commits:** `6c9e084` → `23fbab7` → `2be0381` → `158a32e` → `eb07d85` → `5a445cf`

## Root cause (confirmed)

Production `GET /api/v1/health/symptoms/taxonomy` returned HTTP 200 with 79 symptoms, but the JSON used `severityNotice` while iOS `SymptomTaxonomyDTO` required non-optional `safetyNotice`. Decode failed → UI showed taxonomy load failure.

Android already accepted either key; iOS did not.

Evidence (production probe): `count=79`, `severityNotice` present, `safetyNotice` absent until API redeploy.

## Fixes shipped

1. Backend taxonomy payload includes both `safetyNotice` and `severityNotice`.
2. iOS decoder accepts either key (works against current production without API deploy).
3. Catalog state machine: loading / loaded / failed / offline-cached.
4. Taxonomy cache + offline draft with client idempotency key.
5. UX: collapsible categories, search on labels, favorites/recents, entry sheet, history edit/delete.
6. Migration `020_symptom_client_request_id` applied on `hiair-prod`.
7. Android: collapsible categories, search without snake_case, memory cache fallback, `clientRequestId`.

## Production API deploy

GitHub Actions `Backend Deploy Production` for this push failed at Cloudflare token verify (`Invalid API Token code=1000`). Local `backend/.secrets/cloudflare_api_token` is also invalid.  
`api.hiair.io` still reports `deploy_git_sha=fa0d91b` (pre-fix). Taxonomy load on device is still fixed by the iOS dual-key decoder.

## Honest status

Physical iPhone retest on TestFlight **build 95** is still required before claiming **SYMPTOM JOURNAL E2E VERIFIED**.

**Current verdict: CODE FIXED — WAITING FOR PHYSICAL RETEST**
