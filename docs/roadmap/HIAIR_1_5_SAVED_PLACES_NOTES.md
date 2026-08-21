# HiAir 1.5 — Saved Places

**Status:** IN PROGRESS (backend core)  
**Branch:** `feat/hiair-1.2-best-time-planner` (stacked)

## Shipped
- Models: `backend/app/models/places.py`
- In-memory repository: `backend/app/services/places_repository.py`
- Additive API:
  - `GET /api/places`
  - `POST /api/places`
  - `DELETE /api/places/{placeId}`
- Tests: `backend/tests/test_places_api.py`

## Scope (v0)
- Per-user saved locations with typed labels (`home`, `work`, `school`, `parents`, `vacation`, `other`)
- Coordinates + optional timezone only — **no forecast or weather synthesis**
- Auth via `get_current_user_id`; list/create/delete isolated per user

## Not yet
- PostgreSQL migration + RLS-backed persistence
- Mobile UI for managing saved places
- Planner / dashboard consumption of saved places
- Place limits by entitlement tier
