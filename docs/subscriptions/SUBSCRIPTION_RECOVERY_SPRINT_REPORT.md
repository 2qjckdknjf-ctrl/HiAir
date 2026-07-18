# P0 Subscription Recovery Sprint — Final Report

**Date:** 2026-07-10  
**Branch:** `main`  
**Verdict:** **ENGINEERING FIXED — WAITING FOR SANDBOX DEVICE VERIFICATION**

---

## 1. Executive Summary

Аудит выявил разрыв между backend entitlement и клиентским `isPremium` на iOS/Android: покупка могла успешно верифицироваться на backend, но Premium UI оставался заблокированным из‑за отсутствия синхронизации локального состояния. Исправлены logout/login flows, entitlement apply после load/activate/cancel, Android parser (ложные срабатывания), реализован Google Play `live` verifier (service account), добавлены безопасные server logs и тесты.

Реальная sandbox E2E на устройстве **не выполнена** в этой сессии: iOS TestFlight sandbox purchase и Android Play Internal требуют owner/device действий.

---

## 2. Reproduced Failure

| Step | Status before fix |
|------|-------------------|
| Store products load | OK (при настроенных IAP в ASC) |
| Purchase UI | OK |
| Store transaction | OK (sandbox) |
| Client → backend verify | OK (stub/JWS decode в prod) |
| DB entitlement | OK (`apply_verified_purchase`) |
| **Mobile `isPremium` refresh** | **FAIL** — не обновлялся после Settings load/activate; Android logout/login не сбрасывал/не подтягивал entitlement |
| Premium UI unlock | **FAIL** — gates читают `session.isPremium` / `settingsViewModel.state.isPremium` |
| Restart/re-login | **PARTIAL** — iOS refresh on Settings appear; Android login без `refreshEntitlement` |
| Restore | OK при успешном verify + apply |

**Точка отказа:** клиентский entitlement state не синхронизировался с backend после verify и при logout/login.

---

## 3. Root Cause

1. **iOS `AppSession.logout()`** не сбрасывал `isPremium` → предыдущий аккаунт мог «наследовать» Premium локально.
2. **iOS `SettingsViewModel`** обновлял только `subscriptionStatus`, без `session.applyEntitlement()` → DEBUG activate/load не открывали Premium gates.
3. **Android logout** очищал SessionStore, но не `isPremium` в ViewModel.
4. **Android login/signup** не вызывали `refreshEntitlement()` → после входа Premium оставался false до cold start.
5. **Android `activateSubscription`/`cancelSubscription`** не применяли entitlement из ответа API.
6. **Android `SubscriptionEntitlementParser`** regex по всему JSON — теоретический false positive на `is_premium` вне блока `entitlement`.
7. **Backend Google `live` verifier** не был реализован → Android prod verify возвращал 503 при `GOOGLE_PLAY_VERIFIER_MODE=live`.

---

## 4. Subscription Architecture (working flow)

```
App Store / Play Billing
    → Mobile purchase + local verification (StoreKit / BillingClient)
    → POST /api/subscriptions/{ios|android}/verify  (auth: Bearer)
    → subscription_store.verify_* (stub or live)
    → subscription_repository.apply_verified_purchase
    → entitlement_service.sync_entitlement_from_subscription
    → user_entitlements.is_premium
    → GET /api/subscriptions/me → entitlement JSON
    → Mobile applyEntitlement / refreshEntitlement
    → isPremium gates (Planner, Insights, Settings, profiles 402)
```

Backend — единственный источник истины. Premium разрешён только при `is_premium=true` из entitlement (active/trialing/grace_period subscription).

---

## 5. Bugs Fixed

| # | Fix |
|---|-----|
| 1 | iOS logout + auth expiry clear `isPremium` |
| 2 | iOS Settings entitlement callback → `session.applyEntitlement` |
| 3 | Android `resetSessionAfterLogout` / `clearEntitlementState` |
| 4 | Android login/signup → `refreshEntitlement` |
| 5 | Android activate/cancel → `applyEntitlementFromSubscriptionJson` |
| 6 | Android parser scopes to `entitlement` object |
| 7 | Google Play live verifier (Subscriptions v2 API + service account JWT) |
| 8 | Safe diagnostic logs on verify endpoints (no tokens/receipts) |
| 9 | Tests: iOS AppSession, Android parser, backend google live |

---

## 6. Files Changed

**Backend:** `app/services/subscription_store.py`, `app/api/subscriptions.py`, `tests/test_subscriptions_entitlements.py`

**iOS:** `AppSession.swift`, `Screens/SettingsView.swift`, `HiAirTests/AppSessionTests.swift`

**Android:** `SubscriptionEntitlementParser.kt`, `SettingsState.kt`, `AppMainActivity.kt`, `SettingsScreenRenderer.kt`, `SubscriptionEntitlementParserTest.kt`

**Docs:** this file

---

## 7. Product Mapping

| Platform | Product ID | Store status | Backend plan |
|----------|------------|--------------|--------------|
| iOS monthly | `com.hiair.premium.monthly` | ASC IAP (TestFlight sandbox) | `premium_monthly` |
| iOS yearly | `com.hiair.premium.yearly` | ASC IAP | `premium_yearly` |
| Android monthly | `hiair_premium_monthly` | Play Console **not created** | `premium_monthly` |
| Android yearly | `hiair_premium_yearly` | Play Console **not created** | `premium_yearly` |

---

## 8. Validation

| Check | Result | Notes |
|-------|--------|-------|
| Backend compileall | PASS | arm64 py3.12 |
| `test_subscriptions_entitlements.py` | PASS | 16/16 |
| Android `SubscriptionEntitlementParserTest` | PASS | |
| iOS HiAirTests (subscription) | PENDING | xcodebuild in CI/local |
| Production deploy | NOT RUN | requires owner deploy path |
| `hiair_final_gate.sh` | NOT RUN | full gate after deploy |

---

## 9. Premium Gate Validation

| Feature | Free | Active | iOS gate | Android gate |
|---------|------|--------|----------|--------------|
| Day plan / planner | 402 | 200 | `session.isPremium` + 402 | `state.isPremium` + 402 |
| Advanced insights | 402 | 200 | 402 → paywall | 402 → paywall |
| Privacy export | **200 (auth)** | 200 | **auth only** — no premium gate | Settings (no gate) |
| Extra profiles | 402 at limit | 200 | Paywall | Paywall |

Все gates должны читать backend-synced `isPremium` после исправлений.

---

## 10. Device / Sandbox Evidence

| Scenario | Result |
|----------|--------|
| iOS TestFlight sandbox purchase | **EXTERNALLY BLOCKED** — device + ASC sandbox tester required |
| Android Play Internal purchase | **EXTERNALLY BLOCKED** — `com.hiair` app not in Play Console |
| Restore | **NOT VERIFIED ON DEVICE** |
| Restart / re-login | **NOT VERIFIED ON DEVICE** |

---

## 11. Remaining Blockers

1. **iOS:** Real TestFlight sandbox purchase on build 65+ with configured IAP products.
2. **Android:** Create `com.hiair` in Play Console, upload signed AAB to Internal Testing, add license testers.
3. **Production secrets:** `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` for `GOOGLE_PLAY_VERIFIER_MODE=live`; Apple App Store Server API crypto validation optional hardening (current: JWS payload decode in `live` mode).
4. **Deploy:** Push backend fixes to `api.hiair.io` via Cloudflare Containers workflow.

---

## 12. Final Verdict

**ENGINEERING FIXED — WAITING FOR SANDBOX DEVICE VERIFICATION**

Кодовая цепочка entitlement sync восстановлена и покрыта тестами. Статус **SUBSCRIPTION E2E VERIFIED** невозможен без реальной sandbox покупки, открывающей Premium UI на устройстве.

---

## Update 2026-07-18 — Request Canceled (build 81)

Physical retest on TestFlight **81**: paywall shows unavailable + **Request Canceled**; catalog empty on device; backend not reached.

ASC API still shows READY_TO_SUBMIT with full prices/availability. Code fix in build **82**: detached `Product.products`, cancel retry, honest copy. Owner must confirm Paid Apps Agreement / Tax / Banking Active.

---

## Update 2026-07-17 — Products not loading (build 80)

Physical retest on TestFlight **build 80**: paywall opened, **prices missing**, Subscribe **non-responsive**, Apple sheet never opened, backend not reached.

Confirmed client defects addressed in build **81**:
- singleton observation via `EnvironmentObject` (not inline `@ObservedObject = .shared`)
- service-owned product load (survives view `.task` cancellation)
- honest catalog UI (no dead Subscribe without `Product`)
- canonical `StoreProductIDs`

ASC products remain `READY_TO_SUBMIT` with prices/availability. Owner: confirm Paid Apps Agreement Active; retest build 81 for prices + sheet before full purchase E2E.

---

## Owner Checklists

### iOS TestFlight sandbox

1. ASC: `com.hiair.premium.monthly` / `.yearly` in subscription group for `com.hiair.app`
2. Sandbox tester account
3. TestFlight build ≥ **82**
4. Flow: login → paywall → **prices visible** → purchase sheet → verify Settings shows Premium → Planner unlocks → kill app → reopen → logout/login → restore

### Android Play Internal

1. Create app `com.hiair` in Play Console
2. Upload signed AAB (Internal Testing)
3. Configure `hiair_premium_monthly` / `yearly` subscriptions with active base plans
4. Add license testers; install from Play opt-in link (not sideload)
5. Set prod `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` + `GOOGLE_PLAY_VERIFIER_MODE=live`

### Troubleshooting

- Verify returns 200 but UI locked → check `GET /api/subscriptions/me` entitlement.is_premium; force `refreshEntitlement`
- Android 503 on verify → `GOOGLE_PLAY_VERIFIER_MODE=live` without service account
- iOS verify_pending → decode/apply failure; check API error in paywall status (no receipt logged)
- Paywall **Request Canceled** → install build ≥ 82; Console `products_load_failed`; confirm Paid Apps Agreement Active
- Paywall no price / dead Subscribe → Console `subsystem:com.hiair.app category:subscription` for `products_load_*`; confirm build ≥ 82; ASC Paid Apps Agreement