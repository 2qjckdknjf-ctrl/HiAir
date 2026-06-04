# Subscription QA Checklist

## Install & free tier

- [ ] Clean install → user is free (`is_premium: false`, `max_profiles: 1`)
- [ ] Second profile creation returns 402 / shows paywall
- [ ] Day plan / insights / privacy export blocked for free user (402)

## iOS (sandbox)

- [ ] Paywall loads StoreKit prices (not hardcoded)
- [ ] Monthly purchase → verify → Premium UI
- [ ] Yearly purchase → verify → Premium UI
- [ ] Restore purchases restores entitlement
- [ ] Cancel in App Store → entitlement expires after webhook/refresh
- [ ] Expired subscription → premium APIs return 402

## Android (license test)

- [ ] Product details load from Play
- [ ] Purchase → acknowledge → backend verify
- [ ] Restore/query purchases
- [ ] Expired token removes premium

## Backend

- [ ] Webhook duplicate events are idempotent
- [ ] Invalid webhook signature → 401
- [ ] `POST /activate` forbidden in production
- [ ] `POST /activate` forbidden when `SUBSCRIPTION_PROVIDER!=stub`

## Failure modes

- [ ] No network during purchase → clear error, no false premium
- [ ] Backend down after store purchase → retry verify/restore
- [ ] Invalid receipt/token → 400, no premium granted
