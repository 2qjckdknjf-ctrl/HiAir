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
| `/api/privacy/export` | Yes | Yes | Yes | export payload | export summary + status text | Final gate + build | DONE |
| `/api/privacy/delete-account` | Yes | Yes | Yes | confirmation request | delete flow clears session/state | Final gate + build | DONE |

## Notes
- iOS and Android now share token refresh + session invalidation behavior.
- Privacy export/delete UX is now exposed on both iOS and Android settings screens.
- Air-domain risk level contract is canonicalized to `low/moderate/high/very_high` with legacy mapping handled only at compatibility boundaries.
