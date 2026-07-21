# HiAir — P0 Symptom Journal Recovery — Final Report

**Date:** 2026-07-21  
**Branch:** `main` @ `c254aff` (+ follow-up test/docs commits)  
**TestFlight:** build **95** VALID (`b5339c77-77e8-499b-859d-d7aa34672ce7`)  
**Internal testers:** group «Первый»

---

## 1. Executive Summary

Загрузка каталога симптомов на устройстве ломалась из‑за mismatch JSON-ключа (`severityNotice` vs обязательный iOS `safetyNotice`), а не из‑за сети/auth/Premium. Исправление в клиенте (dual-key decode) + UX redesign каталога поставлены в TestFlight **build 95**. Production API ещё на SHA `fa0d91b` (Cloudflare deploy token invalid). Интерактивный E2E на iPhone не закрыт: Maestro не видит CoreDevice, review-credentials для API smoke невалидны.  
**Verdict: CODE FIXED — WAITING FOR PHYSICAL RETEST**

---

## 2. Reproduced Failure

| Step | Result | Evidence |
|------|--------|----------|
| Open Symptoms on prior TF build | FAIL — «Не удалось загрузить список» | Device report / prior cert |
| Taxonomy request sent? | YES | `GET /api/v1/health/symptoms/taxonomy` |
| Authorization required? | NO (public) | curl 200 without auth |
| HTTP status | 200 | prod probe |
| JSON returned? | YES, count=79, 10 categories | prod probe |
| Schema vs iOS parser | FAIL | missing `safetyNotice`, has `severityNotice` |
| profileId lost? | NO (taxonomy independent) | APIClient fetch without profile |
| Debug API URL? | NO in Release | `INFOPLIST_KEY_API_BASE_URL=https://api.hiair.io` |
| Premium gate? | NO | public taxonomy |
| `.task` / ViewModel recreate? | Not root cause | `@StateObject` owner; decode error primary |
| Failure domain | **taxonomy decode** | iOS catch → `taxonomyFailed` |

---

## 3. Root Cause

1. **Load blocker:** iOS `SymptomTaxonomyDTO` required non-optional `safetyNotice`; production payload shipped only `severityNotice` → decode throw → failed UI.  
2. **UX blocker:** flat dense listing of ~79 symptoms with low readability / poor scan path.

---

## 4. API Contract

| Endpoint | Method | Result |
|----------|--------|--------|
| `/api/v1/health/symptoms/taxonomy` | GET | Public 200; count 79; dual-key client OK; `safetyNotice` pending API redeploy |
| `/api/symptoms/history` | GET | Auth; soft-delete filtered after fix |
| `/api/v1/health/symptoms` | POST | Auth; `clientRequestId` / `Idempotency-Key` (needs API+DB; DB column applied) |
| `/api/v1/health/symptoms/{id}` | PATCH | Auth |
| `/api/v1/health/symptoms/{id}` | DELETE | Auth soft-delete |
| `/api/v1/health/symptoms/favorites` | GET/POST | Auth |
| `/api/v1/health/symptoms/custom` | GET/POST | Auth |

---

## 5. UX Before / After

| Area | Before | After |
|------|--------|-------|
| Title | Generic journal | «Как вы себя чувствуете?» |
| Catalog | Flat wall of pills | Collapsible categories + counts |
| Search | Weak / mixed | Label+category, fold/debounce, clear |
| Quick access | Favorites only | Recents + favorites |
| Entry | Inline form wall | Sheet: severity/onset/ongoing + «Подробнее» |
| History | Missing/weak | Grouped Today/Yesterday/date, edit/delete |
| Errors | Connection copy / empty risk | Failed card with Retry + Check connection |
| Offline | Hard fail | Cached taxonomy + offline draft |

---

## 6. Catalog

| Item | Result |
|------|--------|
| Returned count | 79 (prod) |
| Categories | 10 |
| Localization | RU labels in taxonomy payload |
| Cache | iOS UserDefaults schema v1; Android memory cache |
| Offline | stale-but-usable when cache present |

---

## 7. Entry Flow

| Scenario | Result |
|----------|--------|
| Select → sheet | CODE READY |
| Severity 1–5 / onset / ongoing | CODE READY |
| Advanced fields | CODE READY behind «Подробнее» |
| Double-tap / saving spinner | CODE READY (`loading` guard) |
| Backend confirm before success | CODE READY |
| Physical device proof | PENDING |

---

## 8. History

| Scenario | Result |
|----------|--------|
| List after save | CODE READY (legacy history + soft-delete filter) |
| Human time (no ISO) | CODE READY |
| Edit / delete confirm | CODE READY |
| Physical proof | PENDING |

---

## 9. Insights Integration

| Scenario | Result |
|----------|--------|
| Entry lands in history dataset | CODE READY (same `symptom_logs`) |
| Insights refresh after save | CODE READY (client reload path) |
| Prod authenticated insights smoke | BLOCKED (review login invalid) |
| Physical proof | PENDING |

---

## 10. Validation

| Check | Result | Notes |
|------|--------|-------|
| Backend compile + health_intelligence tests | PASS | arm64 `.tools/py` |
| iOS `SymptomTaxonomyDTOTests` | PASS | 3 cases |
| Android `SymptomTaxonomyParseTest` | PASS | dual-key |
| `hiair_final_gate.sh` | NOT RE-RUN this closeout | prior arm64 JDK fix on main |
| Prod taxonomy public | PASS | count=79 dual-key |
| Prod API redeploy | FAIL | CF token 403 |
| Prod auth CRUD smoke | FAIL | review credentials invalid |

---

## 11. TestFlight

| Build | Commit | Status | Testers |
|-------|--------|--------|---------|
| 95 | `eb07d85` (+ docs) | **VALID** | Internal «Первый» |
| 94 | prior | VALID | — |

Device evidence: iPhone 17 Pro has `com.hiair.app` **0.1.0 (95)** installed; process launched via `devicectl`.

---

## 12. Physical Retest

| Scenario | Result |
|----------|--------|
| Install build 95 | PASS (installed) |
| Launch app | PASS (`devicectl` launch) |
| Catalog loads / search / categories / save / history / edit / delete / offline / Insights | **PENDING interactive** |
| Maestro on device | BLOCKED (CoreDevice not visible to Maestro; only simulators listed) |
| Device OSLog collect | BLOCKED (requires root `log collect`) |

---

## 13. Android Parity

| Scenario | Result |
|----------|--------|
| Taxonomy load + dual-key | PASS (code) |
| Collapsible categories | PASS (code) |
| Search without snake_case | PASS (code) |
| Cache fallback | PASS (memory) |
| History / edit / delete UI | PARTIAL vs iOS sheet flow |
| Offline draft queue | PARTIAL (create idempotency key only) |

---

## 14. Remaining Blockers

1. **Physical interactive retest** on build 95 (Maestro/CoreDevice gap).  
2. **Cloudflare `CLOUDFLARE_API_TOKEN` invalid** — blocks shipping backend `safetyNotice` + server-side idempotency to `api.hiair.io` (client still works).  
3. **App Store review test credentials invalid** for authenticated prod CRUD smoke.

---

## 15. Final Verdict

**CODE FIXED — WAITING FOR PHYSICAL RETEST**

`SYMPTOM JOURNAL E2E VERIFIED` запрещён до ручного/автоматизированного прохода save→history→Insights на физическом iPhone с build 95.
