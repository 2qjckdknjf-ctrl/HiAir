# iOS Real Device QA Script

Status: NEEDS_MANUAL_QA

## Preconditions

- Signed build installed on physical iPhone.
- Staging API URL configured.
- Test account available.
- APNs configured if push E2E is in scope.

## Test Script

| Step | Expected result | Status |
|---|---|---|
| Install/open app | App launches without crash | NOT_VERIFIED |
| Onboarding | Persona/sensitivity/location profile can be set | NOT_VERIFIED |
| Signup/login | Bearer session is created and persisted | NOT_VERIFIED |
| Profile selection | Selected persona/profile persists after restart | NOT_VERIFIED |
| Dashboard risk | Dashboard refresh uses authenticated API | NOT_VERIFIED |
| Planner | Planner loads safe windows/day plan | NOT_VERIFIED |
| Symptom log | Symptom submission succeeds or shows safe error | NOT_VERIFIED |
| Settings | Settings load/save works | NOT_VERIFIED |
| Logout/login persistence | Logout clears session; login restores access | NOT_VERIFIED |
| Push prompt | Permission prompt appears after auth | NOT_VERIFIED |
| APNs token registration | Token upload attempt reaches backend | NOT_VERIFIED |
| Offline state | App does not crash; user sees safe failure | NOT_VERIFIED |
| Privacy export/delete API | Export/delete verified via API or linked support flow | NOT_VERIFIED |

## Evidence Required

- Device model/iOS version.
- Build number.
- Screenshots for core screens.
- API logs for auth/dashboard/symptoms/settings.
- Push token upload log if APNs is configured.
