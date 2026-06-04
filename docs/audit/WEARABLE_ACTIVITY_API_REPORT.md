# Wearable Activity — API Report

**Router:** `backend/app/api/wearables.py`  
**Prefix:** `/api/v1/wearables`

## Endpoints

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| POST | `/consent` | Required | Upsert consent; sets `accepted_at`, clears `revoked_at` |
| DELETE | `/consent` | Required | Sets `revoked_at`; optional `source` query |
| POST | `/daily-summary` | Required | Upsert daily aggregate; **403 without active consent** |
| POST | `/hourly-summary` | Required | Upsert hourly aggregate; **403 without active consent** |
| GET | `/today` | Required | Consent + today summary + personal load |
| DELETE | `/data` | Required | Delete summaries + revoke consent |

## Validation

Pydantic limits on `backend/app/models/wearable.py`:

- stepsTotal: 0–100,000
- heartRateAvg: 30–230
- heartRateMin: 25–220
- heartRateMax: 30–240
- restingHeartRateAvg: 30–140

## Security

- `user_id` from JWT/session only (`get_current_user_id`)
- No user_id in request body as authority
- Consent gate on summary upload

## Tests

`backend/tests/test_wearables_api.py` — consent, revoke, upsert, validation, delete, auth rejection.

## Privacy Export Integration

`privacy_repository.export_user_data` extended with wearable tables.
