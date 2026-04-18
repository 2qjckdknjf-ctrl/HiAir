# Technical Decisions (Step 2)

## Fixed choices

- Mobile: Native (`mobile/ios` + `mobile/android`)
- Backend: Python FastAPI
- Database: PostgreSQL

## Pending choices

- Environmental APIs: selected for MVP v1.
  - Weather: OpenWeatherMap
  - AQI: WAQI

## Rationale

- Native mobile gives maximum control over permissions and future HealthKit/Health Connect integrations.
- FastAPI is fast to ship for MVP and has a clean API-first model.
- PostgreSQL is reliable for structured data and analytics-friendly history tables.
