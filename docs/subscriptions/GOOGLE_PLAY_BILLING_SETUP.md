# Google Play Billing — HiAir Premium

## Product IDs

| Plan | Product ID |
|------|------------|
| Monthly | `hiair_premium_monthly` |
| Yearly | `hiair_premium_yearly` |

## Play Console

1. Monetize → Products → Subscriptions
2. Create subscription products with base plans (monthly / yearly)
3. Activate products in testing track before internal testing

## License testers

- Settings → License testing → add Gmail accounts for sandbox purchases

## Real-time developer notifications

- Configure Pub/Sub topic linked to Play Console
- Push decoded JSON to `POST /api/subscriptions/webhook/google`
- Set `SUBSCRIPTION_WEBHOOK_SECRET` and pass token via `X-Goog-Channel-Token` (or HMAC header per your gateway)

## Service account (live verification)

- Create Google Cloud service account with Play Developer API access
- Download JSON key → `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
- Set `GOOGLE_PLAY_VERIFIER_MODE=live` in production backend

## Client

- Package: `com.hiair`
- Billing Library 7.x (`billing-ktx`)
- Purchases must be **acknowledged**; app calls `POST /api/subscriptions/android/verify` after purchase

## Manage subscription

- Link: `https://play.google.com/store/account/subscriptions`
