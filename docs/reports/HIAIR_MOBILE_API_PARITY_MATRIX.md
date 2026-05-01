# HiAir Mobile API Parity Matrix

| Endpoint | iOS | Android | Auth | Request/Response | Error/Empty/Offline | Coverage | Status |
|---|---|---|---|---|---|---|---|
| `/api/auth/signup` | Yes | Yes | No | AuthRequest/AuthResponse | Error text shown | Manual + compile | DONE |
| `/api/auth/login` | Yes | Yes | No | AuthRequest/AuthResponse | Error text shown | Manual + compile | DONE |
| `/api/auth/refresh` | Yes (auto) | Yes (auto) | Refresh token | RefreshTokenRequest/AuthResponse | On fail: forced logout | Build + runtime path | DONE |
| `/api/dashboard/overview` | Yes | Yes | Yes | query + overview response | fallback error UI | Manual | DONE |
| `/api/air/current-risk` | Yes | Yes | Yes | `profileId` query | fallback states | Manual | DONE |
| `/api/air/day-plan` | Yes | Yes | Yes | `profileId` query | fallback states | Manual | DONE |
| `/api/planner/daily` | Yes | Yes | No | planner query/response | loading + error | Manual | DONE |
| `/api/symptoms/log` | Yes | Yes | Yes | SymptomLogRequest/Response | submit error states | Manual | DONE |
| `/api/insights/personal-patterns` | Yes | Yes | Yes | profile + window + lang | loading/empty/error | Manual | DONE |
| `/api/briefings/schedule` (GET/PUT) | Yes | Yes | Yes | schedule models | retry/error UI | Manual | DONE |
| `/api/settings` (GET/PUT) | Yes | Yes | Yes | settings models | retry/error UI | Manual | DONE |
| `/api/privacy/export` | Not fully surfaced UI | Not fully surfaced UI | Yes | export payload | backend exists | Backend tests | PARTIAL |
| `/api/privacy/delete-account` | Not fully surfaced UI | Not fully surfaced UI | Yes | confirmation request | backend exists | Backend tests | PARTIAL |

## Notes
- iOS and Android now share token refresh + session invalidation behavior.
- Remaining parity gap is privacy export/delete UX exposure in mobile UI despite backend support.
- Legacy risk aliasing (`medium`/`moderate`) still exists in compatibility layer and should be normalized in a dedicated contract cleanup cycle.
