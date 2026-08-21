# HiAir 1.5 — Saved Places

**Status:** IN PROGRESS (backend + Settings UI + planner placeId)  
**Branch:** `feat/hiair-1.2-best-time-planner` (stacked)

## Shipped
- Models: `backend/app/models/places.py`
- Repository: Postgres (`021_saved_places.sql`) with in-memory fallback
- Additive API:
  - `GET /api/places`
  - `POST /api/places`
  - `DELETE /api/places/{placeId}`
- Activity plan optional `placeId` for forecast location override
- Family caregiver stub: `/api/family/members`
- Tests: `test_places_api.py`, `test_family_api.py`
- iOS/Android Settings CRUD; iOS planner place picker

## Scope (v0)
- Per-user saved locations with typed labels (`home`, `work`, `school`, `parents`, `vacation`, `other`)
- Coordinates + optional timezone only — **no forecast or weather synthesis**
- Auth via `get_current_user_id`; list/create/delete isolated per user

## Not yet
- Apply migration on production Supabase
- Android planner place spinner UI polish
- Place limits by entitlement tier
- Family risk aggregation UI
