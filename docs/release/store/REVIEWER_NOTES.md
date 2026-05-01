# Reviewer Notes

## Product Scope
HiAir is a wellness app. It does not provide medical diagnosis, emergency triage, or treatment instructions.

## Core Flows to Review
1. Signup/login.
2. Onboarding with profile and location fields.
3. Dashboard current risk + recommended actions.
4. Planner + symptom logging.
5. Insights screen (personal patterns when enough data exists).
6. Settings (briefing schedule, notification toggles, subscription scaffold, privacy actions).

## API and Account Notes
- API endpoints are auth-protected with bearer JWT.
- Refresh token flow auto-recovers expired access tokens.
- If refresh fails, client clears session and returns to auth.

## Test Account Placeholder
- Email: `<REVIEW_TEST_EMAIL>`
- Password: `<REVIEW_TEST_PASSWORD>`

## Known Review Constraints
- Push live delivery requires APNs/FCM production credentials (external setup).
- Store metadata and legal text are draft until owner/legal sign-off.
