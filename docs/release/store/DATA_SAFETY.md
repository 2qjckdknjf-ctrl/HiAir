# Data Safety Draft — HiAir Android 1.0 (188)

Use these answers on Play Console → Policy → App content → Data safety.
Checked 2026-08-21 against current Play Data safety guidance.

## Data collection and security overview

- Does the app collect or share required user data types? **Yes**
- All user data encrypted in transit? **Yes** (HTTPS to `https://api.hiair.io` and Supabase)
- Users can request that data is deleted? **Yes**
- Independent security review (SOC 2 / ISO 27001 / etc.)? **No**

## Data Collected

| Type | Collected | Optional | Shared | Purpose |
|---|---|---|---|---|
| Email | Yes | Required for account | No (service provider: Supabase Auth / our API) | App functionality, account management |
| User IDs | Yes | Required | No | App functionality, account management |
| Approximate location | Yes | User can deny OS permission | No | App functionality (air/heat risk for area) |
| Precise location | Yes when granted | User can deny | No | App functionality (air/heat risk for area) |
| Health info | Optional Health Connect daily/hourly aggregates + user-entered symptoms | Yes | No | App functionality, personalization (wellness, not ads) |
| Physical activity | Optional Health Connect steps/distance/energy | Yes | No | App functionality, personalization |
| Device or other IDs | Push token when notifications enabled | Yes | No (FCM as service provider) | App functionality (alerts) |
| Advertising ID | **No** | — | — | Manifest removes `AD_ID` |

## Data Usage

- Core app functionality (dashboard, planner, insights, briefings).
- Personalization of non-medical recommendations and alert thresholds.
- Security/session continuity for authenticated API access.
- **Not** advertising or marketing profiling.
- **Not** sold.

## Data Sharing / Selling

- No sale of personal data.
- No ad-network sharing.
- Supabase and Cloudflare/API hosting are service providers processing data on our behalf (not “shared” under Play’s sharing exceptions when used only to operate the app).

## User Controls

- Export: in-app + `GET /api/privacy/export`
- Delete account/data: in-app confirmation + `POST /api/privacy/delete-account`
- Health Connect: deny still uses the app; revoke/delete is local-first fail-closed
- Notification preference toggles in Settings

## Store listing URL

Privacy policy: https://hiair.io/privacy/
