# HiAir 1.5 — Saved Places

**Status:** IN PROGRESS (backend + Settings UI + planner placeId; prod smoke PASS on `408ec1c3`)  
**Branch:** `feat/hiair-1.2-best-time-planner` (stacked)

## Shipped
- Models: `backend/app/models/places.py`
- Repository: Postgres (`021_saved_places.sql`) with in-memory fallback
- Additive API:
  - `GET /api/places`
  - `POST /api/places`
  - `DELETE /api/places/{placeId}`
- Activity plan optional `placeId` for forecast location override
- Family caregiver stub: `/api/family/members` + `GET /api/family/risk-overview`
- Persistence: `023_family_member_links.sql` (applied on prod Supabase)
- Tests: `test_places_api.py`, `test_family_api.py`, `test_family_risk_overview_api.py`
- iOS/Android Settings CRUD; iOS planner place picker
- Family links UI (Settings): list/add/delete members; profile ownership validated server-side
- Family risk line per linked member in Settings (real `air_risk_engine`, no synthesis)
- Family risk overview card on Dashboard when members are linked (iOS + Android)
- Android planner saved-place picker

## Scope (v0)
- Per-user saved locations with typed labels (`home`, `work`, `school`, `parents`, `vacation`, `other`)
- Coordinates + optional timezone only — **no forecast or weather synthesis**
- Auth via `get_current_user_id`; list/create/delete isolated per user

## Not yet
- [x] Place limits by entitlement tier (free: 3, premium: 25)
- [x] Mobile 402 limit message when adding places (iOS + Android)
- [x] Travel mode — temporary location override via saved place (`/api/travel/session`)
- Mobile Settings travel toggle UI
