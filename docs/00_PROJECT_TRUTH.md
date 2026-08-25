# 00 Project Truth

- Repository root: `/Users/alex/Projects/HIAir`
- Product: HiAir wellness app (backend + iOS + Android).
- Backend: FastAPI + PostgreSQL + deterministic risk engine.
- Mobile: native iOS (SwiftUI) and Android (Kotlin views).
- Auth: JWT access tokens + refresh token rotation.
- Scope truth: wellness support, not medical diagnosis/treatment.
- Release truth: closed beta target; public launch requires external legal/store credentials and manual console tasks.
- Forecast truth (HiAir 1.1, branch `feat/hiair-1.1-forecast-truth`): planner hours and safe windows come from real Open-Meteo hourly points or are marked unavailable. UV/PM10/wind are provider values or null. Production deploy + physical-device QA are still required before READY.
