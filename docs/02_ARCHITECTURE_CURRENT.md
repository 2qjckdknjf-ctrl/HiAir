# 02 Architecture Current

## Backend
- FastAPI app in `backend/app/main.py`.
- Domain APIs under `backend/app/api`.
- Data access via psycopg repositories under `backend/app/services`.
- SQL migrations under `backend/sql`.
- Deterministic risk engines and alert orchestration under services.

## iOS
- SwiftUI app in `mobile/ios/HiAir`.
- Session persisted in `AppSession` and propagated to `APIClient`.
- Auth auto-refresh and forced session expiry handling implemented.

## Android
- Kotlin app in `mobile/android/app/src/main/java/com/hiair`.
- Session persisted in `SessionStore`.
- `ApiClient` performs automatic refresh + retry on `401`.

## Ops and QA
- Backend gate script: `backend/run_gate.sh`.
- Final multi-platform gate: `scripts/release/hiair_final_gate.sh`.
- CI workflows in `.github/workflows`.
