# Morning Briefing MVP

Daily card built from real risk/planner data:

- temperature / heat context
- AQI
- overall risk level and numeric score
- best walk window
- avoid-outdoor window
- personal note (RU/EN via `preferred_language`)
- optional wearable note when metrics exist

## API

- Authenticated: `GET /api/insights/morning-briefing?profile_id=...`
- Guest/public: `GET /api/insights/morning-briefing/public?persona=...&lat=...&lon=...`

## Mobile surfaces

- Dashboard top card (iOS/Android)
- Push foundation: reuse `notification_text` from dashboard overview when enabled
