# App Store Connect — HiAir Premium

## Product IDs

| Plan | Product ID |
|------|------------|
| Monthly | `com.hiair.premium.monthly` |
| Yearly | `com.hiair.premium.yearly` |

## Subscription group

- Group name: **HiAir Premium**
- Level: single group with monthly + yearly auto-renewable subscriptions

## Localization

- Display name: **HiAir Premium**
- Description: wellness air-quality guidance (not medical advice)

## Review notes

- Restore purchases: Settings → Upgrade → **Restore purchases**
- Sandbox account required for review
- Backend verifies StoreKit transactions at `POST /api/subscriptions/ios/verify`
- Privacy: https://hiair.io/privacy/ — Terms: https://hiair.io/terms/

## Bootstrap (API)

If products are missing in App Store Connect:

```bash
cd backend && .venv/bin/python ../scripts/ops/bootstrap_app_store_subscriptions.py
.venv/bin/python ../scripts/ops/check_app_store_iap.py
```

Requires `backend/.secrets/AuthKey_VCL6R84SP3.p8` and `apple_issuer_id`.

After bootstrap, run `check_app_store_iap.py` and fix any row that shows `prices=0` or `review_screenshot=no`:

1. **Subscription Prices** — App Store Connect → Monetization → Subscriptions → each product → **Subscription Prices** → set USA baseline (e.g. $4.99 monthly / $39.99 yearly). The API key often cannot set prices (409); an account with **Finance** or **Admin** role must do this in the dashboard.
2. **Review screenshot** — same product page → **App Review Information** → upload any paywall screenshot (required for `READY_TO_SUBMIT`).
3. **Link to app version** — App Store Connect → your app → **TestFlight** or version → **In-App Purchases and Subscriptions** → add both HiAir Premium products.
4. Wait 15–60 minutes, then retry Premium in the app (sandbox Apple ID).

## Sandbox testing

1. Create Sandbox tester in App Store Connect → Users and Access → Sandbox
2. Sign out of production App Store on device; sign in with sandbox Apple ID when prompted
3. Purchase monthly/yearly; confirm Premium unlocks in app and `GET /api/subscriptions/me` shows `is_premium: true`

## Server (production)

- `APPLE_STORE_VERIFIER_MODE=live`
- `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` (App Store Connect API key)
- `SUBSCRIPTION_WEBHOOK_SECRET` for `POST /api/subscriptions/webhook/apple`
- App Store Server Notifications V2 → backend webhook URL
