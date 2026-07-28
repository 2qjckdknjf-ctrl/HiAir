# Subscription Release Readiness

## Current status: **ARCHITECTURE READY**

Code, unit tests, and CI-style builds are green. **Store sandbox purchases are not yet verified on device** — do not promote to STORE SANDBOX READY until [SUBSCRIPTION_QA_CHECKLIST.md](./SUBSCRIPTION_QA_CHECKLIST.md) passes on real sandbox accounts.

---

## Production rules (mandatory)

| Rule | Detail |
|------|--------|
| **No stub premium in production** | `SUBSCRIPTION_PROVIDER=stub` and `APPLE_STORE_VERIFIER_MODE=stub` / `GOOGLE_PLAY_VERIFIER_MODE=stub` must **not** be used to grant premium in `APP_ENV=production` or `staging`. |
| **Live verifiers** | Production requires `APPLE_STORE_VERIFIER_MODE=live` + Apple API key material, and `GOOGLE_PLAY_VERIFIER_MODE=live` + `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. Deploy/`check_env_security` **reject** Google stub in production/staging. Live Google parsing is fail-closed (exact **unique** product match — ambiguous duplicate `lineItems` rejected; required `expiryTime` / `latestOrderId` / `subscriptionState`; `prepaidPlan` ⇒ `auto_renew=false`; `autoRenewingPlan.autoRenewEnabled` must be an explicit boolean; no plan-length / token-hash / default-`True` synthesis). |
| **Manual activate/cancel** | `POST /api/subscriptions/activate` and `/cancel` only when `SUBSCRIPTION_PROVIDER=stub` **and** `APP_ENV` is development/test — blocked in staging/production. |
| **Webhook secret** | `SUBSCRIPTION_WEBHOOK_SECRET` required (≥16 chars) for any externally reachable webhook. |

---

## Automated verification (repo)

```bash
# Backend
cd backend && ../.venv/bin/python -m pytest -q

# Android
cd mobile/android && ./gradlew test assembleDebug

# iOS
cd mobile/ios && xcodebuild -project HiAir.xcodeproj -scheme HiAir -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

**Last run (2026-06-16):** iOS build **12** — entitlement refresh no longer clears Premium on transient errors; StoreKit `AppStore.sync()` + retry; paywall trusts verify response; login refreshes entitlement. IAP in ASC: **READY_TO_SUBMIT** (175 territories, review screenshots complete).

### iOS E2E flow (wired)

1. Paywall → StoreKit purchase → `/ios/verify` (stub JWS accepted in dev; real JWS preferred when available).
2. Restore → `Transaction.currentEntitlements` → `/restore` with `AppStore.sync()`.
3. `AppSession.refreshEntitlement()` from `/me` — **does not** downgrade Premium on network errors.
4. TestFlight build **≥12**: Settings → Apple Health → Connect must show **system Health sheet** (not iOS Settings).

### Android E2E flow (wired)

1. Settings → **Upgrade to Premium** (or 402 on planner/insights).
2. Paywall shows monthly/yearly prices from Play `ProductDetails`.
3. Purchase → acknowledge → `POST /api/subscriptions/android/verify` (Premium from verify response before `/me` refresh).
4. Restore → `queryPurchasesAsync` → verify each token.
5. `GET /api/subscriptions/me` → `is_premium` updates UI gates.

## Platform E2E status

| Platform | Implemented | CI/build | Sandbox purchase verified |
|----------|-------------|----------|---------------------------|
| **Backend** | Entitlements + verify + webhooks + guards | pytest green | N/A (use stub verifier in dev) |
| **iOS** | StoreKit 2 + Paywall + `/ios/verify` + restore | xcodebuild green (build 12) | **No** — requires sandbox device QA |
| **Android** | BillingClient + Paywall UI + `/android/verify` + restore | test + assembleDebug green | **No** — requires Play Console + device |

---

## Environment variables

| Variable | Development | Production |
|----------|-------------|------------|
| `SUBSCRIPTION_PROVIDER` | `stub` | `apple` / `google` (not `stub`) |
| `APPLE_STORE_VERIFIER_MODE` | `stub` | **`live`** |
| `APPLE_STORE_ENVIRONMENT` | `sandbox` | **`production`** |
| `APPLE_APP_APPLE_ID` | empty | **numeric App Store Connect Apple ID** |
| `GOOGLE_PLAY_VERIFIER_MODE` | `stub` | **`live`** |
| `SUBSCRIPTION_WEBHOOK_SECRET` | optional locally | **required** |
| `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` | — | required when live |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | — | required when live |

---

## Gate checklist

| Gate | ARCHITECTURE READY | STORE SANDBOX READY | PRODUCTION READY |
|------|--------------------|---------------------|------------------|
| Backend pytest | ✅ | ✅ | ✅ |
| Premium API guards | ✅ | ✅ | ✅ |
| iOS xcodebuild | ✅ | ✅ | ✅ |
| Android test + assembleDebug | ✅ | ✅ | ✅ |
| Paywall + billing wired | ✅ | ✅ | ✅ |
| Sandbox purchase on device | ❌ | ✅ required | ✅ |
| Live store verifiers | ❌ | optional | ✅ required |
| QA checklist signed | ❌ | ✅ required | ✅ required |

---

## Manual steps before next status bump

1. Create store products (see setup docs).
2. Apply DB migration on staging/prod.
3. Configure webhook URLs + secrets.
4. Execute sandbox QA on iOS and Android.
5. Only then set status to **STORE SANDBOX READY**.

---

## Product IDs

- iOS: `com.hiair.premium.monthly`, `com.hiair.premium.yearly`
- Android: `hiair_premium_monthly`, `hiair_premium_yearly`
- Internal: `premium_monthly`, `premium_yearly`
