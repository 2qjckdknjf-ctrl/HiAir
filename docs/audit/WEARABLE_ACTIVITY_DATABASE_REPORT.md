# Wearable Activity — Database Report

**Migration:** `backend/sql/014_wearable_activity.sql`

**Status:** Applied on `hiair-prod` (`qhxesaemlhzwbunpqjoo`) via Supabase migration `014_wearable_activity` on 2026-06-04.

## Tables Added

| Table | Purpose |
|-------|---------|
| `health_data_consents` | Explicit consent per user+source with version and revoke timestamps |
| `wearable_daily_summaries` | Daily aggregates (steps, HR, resting HR) |
| `wearable_hourly_summaries` | Hourly aggregates (steps, HR avg/max) |

All tables reference `auth.users(id) ON DELETE CASCADE`.

## RLS Policies

Direct ownership pattern (same as `003_supabase_auth_rls.sql`):

- SELECT/INSERT/UPDATE/DELETE where `auth.uid() = user_id`
- Applied to all three wearable tables

Backend service-role bypasses RLS for server-side operations as per existing HiAir convention.

## Indexes

- `health_data_consents`: user_id, user_id+source (unique), accepted_at/revoked_at
- `wearable_daily_summaries`: user_id+date, user_id+source
- `wearable_hourly_summaries`: user_id+hour_start, user_id+source

## Why No Raw Stream Storage

- Minimizes sensitive data exposure
- Sufficient for wellness load scoring v1
- Reduces GDPR/CCPA surface
- Aligns with App Store / Play Data Safety disclosures

## User Data Deletion

1. `DELETE /api/v1/wearables/data` — removes all daily/hourly summaries and revokes consent
2. `POST /api/privacy/delete-account` — cascades via FK on user deletion
3. Privacy export includes consent + summary records
