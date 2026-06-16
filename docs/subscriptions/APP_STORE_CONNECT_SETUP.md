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
.venv/bin/python ../scripts/ops/finalize_app_store_subscriptions.py
.venv/bin/python ../scripts/ops/check_app_store_iap.py
```

Requires `backend/.secrets/AuthKey_VCL6R84SP3.p8` and `apple_issuer_id`.

`finalize_app_store_subscriptions.py` propagates USA prices to all territories (required for `READY_TO_SUBMIT`) and uploads the review screenshot (`docs/brand/store-assets/subscription-review-screenshot.png`, 640×920).

Expected `check_app_store_iap.py` output:

```
state=READY_TO_SUBMIT prices=175 availability=yes review_screenshot=yes (UPLOAD_COMPLETE)
```

If products are still `MISSING_METADATA`, re-run `finalize_app_store_subscriptions.py`.

For first App Store submission, link subscriptions to the app version in App Store Connect → **Distribution** → version **1.0** → **In-App Purchases and Subscriptions** (after a build is attached). Sandbox/TestFlight purchases work once state is `READY_TO_SUBMIT`; wait 15–60 minutes after finalize.

## Sandbox testing

1. Create Sandbox tester in App Store Connect → Users and Access → Sandbox
2. Sign out of production App Store on device; sign in with sandbox Apple ID when prompted
3. Purchase monthly/yearly; confirm Premium unlocks in app and `GET /api/subscriptions/me` shows `is_premium: true`

## Server (production)

- `APPLE_STORE_VERIFIER_MODE=live`
- `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` (App Store Connect API key)
- `SUBSCRIPTION_WEBHOOK_SECRET` for `POST /api/subscriptions/webhook/apple`
- App Store Server Notifications V2 → backend webhook URL
