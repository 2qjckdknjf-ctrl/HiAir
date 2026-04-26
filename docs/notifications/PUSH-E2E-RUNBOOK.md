# Push E2E runbook (Closed Beta)

## Preconditions

1. Backend running with Postgres (`DATABASE_URL`), JWT secret, and user auth working.
2. `NOTIFICATIONS_PROVIDER_MODE` set appropriately (`stub` for safe local runs; `live` only with real secrets in a secret manager — **never commit** keys).
3. **iOS physical device** with a development/distribution provisioning profile that includes Push capability.
4. **Android physical device** with `google-services.json` present **locally** (not in git) and Firebase Cloud Messaging enabled for package `com.hiair`.

## iOS sequence

1. Install signed build on device.
2. Sign in so Keychain holds bearer token.
3. Open Settings → trigger notification permission (or fresh install flow).
4. Accept permission; confirm Xcode/device logs show `Push: token upload attempted` then `Push: token registered with backend`.
5. On backend DB, confirm device token row for user (or use privacy export if permitted).
6. Trigger a notification dispatch path appropriate to your env (`stub` vs `live`) and verify delivery attempt records (`/api/notifications/delivery-attempts` with admin token for ops review).

## Android sequence

1. Place `google-services.json` locally; add Firebase Messaging client if not already generating `fcm_token` in `hiair_push` prefs (today’s OSS build logs **NO-OP** until a writer exists).
2. Install build; sign in.
3. Grant POST_NOTIFICATIONS on Android 13+.
4. Filter Logcat for `HiAirPush`; expect `token upload attempted` → `token registered` when token exists.

## Backend checks

```bash
curl -sS http://127.0.0.1:8000/api/health
```

Preflight (requires `NOTIFICATION_ADMIN_TOKEN` in env for ops endpoints — **not** used by user device-token route):

```bash
cd backend
set -a && source .env.local && set +a
../.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"
```

## Evidence to attach for RC

- Redacted log excerpt showing successful device-token POST (no bearer token values).
- Screenshot of Firebase/ASC configuration (no private keys in ticket).
