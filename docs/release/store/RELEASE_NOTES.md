# Release Notes (Draft)

## HiAir 0.1.0-beta (2026-07-07)

### Highlights
- Live environmental data pipeline (Open-Meteo): live → cached → sample with source labels in UI.
- Dashboard, planner, and risk endpoints use unified environment resolver and shared scoring.
- Privacy export available to all authenticated users (GDPR baseline).
- Aurora Calm v2 visuals; Personal Patterns and Morning Briefing integrated.
- Wearable activity v1 (HealthKit / Health Connect) with consent and daily aggregates.

### Security and Reliability
- Auth hardening with refresh token rotation and rate limiting.
- Protected environment fails fast on insecure runtime auth settings.
- Post-deploy smoke: health, environment sample, privacy export gate verification.
- Final release gate script fixed for arm64 Mac (`.venv312`).

### Known Limits (operator actions required)
- Device QA not yet executed (iPhone offline, no adb).
- TestFlight / Play Internal Testing uploads pending.
- Sandbox IAP: architecture ready, on-device verification pending.
- Live push delivery requires APNs/FCM production credentials on device.

### Upgrade Notes
- **Release builds** must be used for production API testing (`https://api.hiair.io`).
- Debug builds continue to target localhost for local backend development.
