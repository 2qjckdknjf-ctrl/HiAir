# 03 API Contracts

## Auth
- `POST /api/auth/signup`
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`
- `GET /api/auth/me`

## Core Wellness APIs
- `GET /api/dashboard/overview`
- `GET /api/planner/daily`
- `GET /api/air/current-risk`
- `GET /api/air/day-plan`
- `POST /api/symptoms/log`
- `GET /api/insights/personal-patterns`
- `GET/PUT /api/briefings/schedule`

## Privacy
- `GET /api/privacy/export`
- `POST /api/privacy/delete-account`

## Contract Notes
- Protected endpoints require bearer auth.
- Legacy `X-User-Id` path is disabled by default and blocked in protected env.
- Air-domain risk levels are canonicalized to `low/moderate/high/very_high`; legacy `medium` is normalized only at compatibility boundaries.

## HiAir 1.1 Forecast Truth
- Planner hours and safe windows must come from real provider forecast points (see `docs/roadmap/HIAIR_1_1_DATA_INTEGRITY_CONTRACT.md`).
- `GET /api/air/day-plan` and `GET /api/air/current-risk` may add optional `dataQuality`, `freshness`, `sources`, `generatedAt`, `forecastAvailable`, `missingMetrics`.
- UV, PM10, and wind are provider values or unavailable — never inferred from temperature / PM2.5 / humidity.
