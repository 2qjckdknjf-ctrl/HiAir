# Subscription Current State Audit

**Date:** 2026-06-04  
**Scope:** Backend, iOS, Android, docs (truth-based, code review)

## 1. What is actually implemented

### Backend

| Area | Status | Evidence |
|------|--------|----------|
| Subscription router | Implemented | `backend/app/api/subscriptions.py` |
| Plans catalog (in-memory) | Implemented | `subscription_repository.PLANS` — `basic_monthly`, `basic_yearly` with hardcoded USD prices |
| User subscription row | Implemented | `user_subscriptions` in `001_init.sql` / `002_*.sql` |
| Webhook ingestion | Implemented | `POST /api/subscriptions/webhook/{provider}` with HMAC `X-Webhook-Signature`, idempotency via `subscription_webhook_events` |
| Provider parsing | Partial | `subscription_provider.py` — only `stub` and `stripe` |
| Manual activate | Dev-gated | Blocked when `APP_ENV` is `production` or `staging` (`_is_protected_env`) |
| Manual cancel | No env gate | Any authenticated user can cancel in any environment |
| Premium API guard | One endpoint | `GET /api/recommendations/daily` returns 402 without active subscription |
| `has_active_subscription` helpers | Implemented | `subscription_repository.py` — used only by recommendations |

### Mobile

| Platform | Store billing | Backend subscription API |
|----------|---------------|---------------------------|
| iOS | **None** (no StoreKit, no `Product.products`) | Settings dev UI: `fetchPlans`, `fetchMySubscription`, `activate`, `cancel` via `APIClient.swift` |
| Android | **None** (no BillingClient) | Same dev-style controls in `SettingsScreenRenderer.kt` / `SettingsState.kt` |

### Configuration

- `SUBSCRIPTION_PROVIDER` default `stub` — `settings.py`, `.env.example`, beta checklist
- `SUBSCRIPTION_WEBHOOK_SECRET` — required for non-stub in `check_env_security.py` (allowed values: `stub`, `stripe` only)
- CI/deploy workflows pass subscription secrets

## 2. Documented only (not in production code path)

- Premium product IDs (`com.hiair.premium.*`, `hiair_premium_*`) — **not in codebase**
- `user_entitlements` table — **not present**
- `provider_transactions` / receipt store — **not present**
- iOS/Android verify & restore endpoints — **not present**
- Apple/Google webhooks (`/webhook/apple`, `/webhook/google`) — **not present**
- StoreKit 2 / Play Billing paywall — **not present**
- Feature matrix (free vs premium limits) — **not enforced** except daily recommendations

## 3. API endpoints (current)

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| GET | `/api/subscriptions/plans` | No | In-memory plans |
| GET | `/api/subscriptions/me` | Yes | `SubscriptionStatusResponse` from `user_subscriptions` |
| POST | `/api/subscriptions/activate` | Yes | Stub-style activation; blocked in staging/production |
| POST | `/api/subscriptions/cancel` | Yes | Sets canceled; **not store-backed** |
| POST | `/api/subscriptions/webhook/{provider}` | Signature | Provider must match `SUBSCRIPTION_PROVIDER` |

**Missing (required for production mobile):**  
`/ios/verify`, `/android/verify`, `/restore`, `/webhook/apple`, `/webhook/google`

## 4. Tables and migrations

| Table | Migration | Purpose |
|-------|-----------|---------|
| `user_subscriptions` | `001_init.sql`, `002_*` | One row per user: plan_id, status, period, provider_subscription_id |
| `subscription_webhook_events` | `001_init.sql` | Idempotency `(provider, event_id)` |

**Missing:** `subscription_plans`, `user_entitlements`, `provider_transactions`, platform/product columns on subscriptions.

## 5. iOS StoreKit

**Not implemented.** No Swift files reference StoreKit, `Product`, `Transaction`, or paywall UI.

## 6. Android Google Play Billing

**Not implemented.** `build.gradle.kts` has no `billing` dependency; no `BillingClient` usage.

## 7. Backend entitlement checks (real guards)

| Feature | Backend guard | Location |
|---------|---------------|----------|
| Daily recommendations | Yes (402) | `app/api/recommendations.py` |
| Extra profiles | **No** | `app/api/profiles.py` — unlimited create |
| Day plan / extended forecast | **No** | `app/api/air.py` `/day-plan` |
| Advanced insights | **No** | `app/api/insights.py` |
| Privacy export | **No** | `app/api/privacy.py` |
| Briefings / custom alerts | **No** | `app/api/briefings.py` |
| Planner hourly | **No** | `app/api/planner.py` (public, no auth) |

## 8. UI-only hiding (no backend enforcement)

- All premium UX is effectively **open** except `/recommendations/daily`
- Mobile has no premium gates; subscription controls are developer/settings tooling
- Onboarding, dashboard, insights, planner accessible without subscription check

## 9. Production risks

1. **No store verification** — premium cannot be sold legitimately on iOS/Android.
2. **Stub activation** — blocked in protected env for `/activate`, but webhook+stripe path could still grant access if misconfigured.
3. **Cancel endpoint** — can mark subscription canceled without store sync in production.
4. **Profile sprawl** — free users can create unlimited family profiles via API.
5. **Privacy export** — GDPR-style export available without premium gate (may be intentional for compliance; product spec says premium export).
6. **Planner endpoint** — unauthenticated hourly planner (separate from subscription but exposure surface).
7. **Wrong plan IDs** — `basic_*` vs required `premium_*` store SKUs.
8. **Stripe as mobile provider** — violates App Store / Play digital goods policy if used for in-app premium.
9. **No restore purchases flow** — App Review risk.
10. **No expired/canceled subscription tests** beyond minimal repository helpers.

## Summary verdict (pre-implementation)

| Criterion | Status |
|-----------|--------|
| StoreKit / Play Billing | FAIL |
| Backend purchase validation | FAIL |
| Entitlements source of truth | FAIL |
| Stub locked in production | PARTIAL (activate only) |
| Free user API bypass | FAIL (most premium APIs open) |
| Restore purchases | FAIL |
| Store setup docs | FAIL |

**Overall:** NOT READY — beta/stub infrastructure only.
