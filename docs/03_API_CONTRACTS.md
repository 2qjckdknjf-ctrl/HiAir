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
