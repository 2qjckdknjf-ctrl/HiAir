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

After bootstrap, open App Store Connect → **Subscriptions** → each product → set **Subscription Prices** (USA baseline propagates to other territories) if API pricing returns 409. Then link products to the TestFlight app version under **In-App Purchases**.

## Sandbox testing

1. Create Sandbox tester in App Store Connect → Users and Access → Sandbox
2. Sign out of production App Store on device; sign in with sandbox Apple ID when prompted
3. Purchase monthly/yearly; confirm Premium unlocks in app and `GET /api/subscriptions/me` shows `is_premium: true`

## Server (production)

- `APPLE_STORE_VERIFIER_MODE=live`
- `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` (App Store Connect API key)
- `SUBSCRIPTION_WEBHOOK_SECRET` for `POST /api/subscriptions/webhook/apple`
- App Store Server Notifications V2 → backend webhook URL
