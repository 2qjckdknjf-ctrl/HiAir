# Android Onboarding/Auth Gate

Status: PARTIAL

## Phase 2 behavior

- Protected navigation targets now route unauthenticated users back to Settings/auth.
- Dashboard, Planner, and Symptoms render only when `userId` and bearer `accessToken` are present.
- Logout clears secure session storage and leaves the user on Settings/auth.
- Android uses Settings as the minimal beta auth/profile setup surface.

## Remaining parity gap

iOS has a dedicated `AuthView` followed by `OnboardingView`. Android still combines auth, notification preferences, default persona, and subscription controls in Settings. This is acceptable for internal beta builds but needs UX/product work before public launch.

Status: NEEDS_MANUAL_QA

## Manual QA

- [ ] Fresh install opens Settings/auth rather than protected dashboard data.
- [ ] Signup/login persists session.
- [ ] Dashboard refresh works after login.
- [ ] Planner/symptom submission require bearer token.
- [ ] Logout clears session and protected tabs route back to Settings/auth.
